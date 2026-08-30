import Foundation
import Supabase

@MainActor
final class UserSyncService {
    private struct RemoteFavorite: Decodable {
        let quote_id: String
    }

    private struct RemoteUserState: Decodable {
        var streak_count: Int
        var last_open_date: String?
        var first_name: String?
        var last_name: String?
        var gender: String?
        var premium_granted: Bool?
        var premium_until: String?
        var freezes_remaining: Int?
        var freeze_period: String?
        var freeze_granted: Int?
        var last_freeze_date: String?
    }

    /// Écritures volontairement séparées : chaque upsert ne transmet que ses propres
    /// colonnes, sinon la mise à jour du streak écraserait le prénom avec une valeur
    /// nulle (et inversement).
    private struct StreakUpdate: Encodable {
        let user_id: String
        var streak_count: Int
        var last_open_date: String?
        var freezes_remaining: Int
        var freeze_period: String?
        var freeze_granted: Int
        var last_freeze_date: String?
    }

    private struct ProfileUpdate: Encodable {
        let user_id: String
        var first_name: String
        var last_name: String
        var gender: String
    }

    struct Profile {
        var firstName: String?
        var lastName: String?
        var gender: Gender?
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    /// Pulls remote favorites and reconciles the streak (server is authoritative across devices).
    /// Returns the merged state to apply locally.
    func syncOnSignIn(userID: String) async -> (
        favoriteIDs: Set<String>?,
        streak: Int?,
        profile: Profile,
        grantedPremium: Bool?
    ) {
        async let favorites = fetchFavorites(userID: userID)
        async let state = reconcileStreak(userID: userID)
        let resolved = await state
        return (await favorites, resolved.streak, resolved.profile, resolved.grantedPremium)
    }

    func saveProfile(userID: String, firstName: String, lastName: String, gender: Gender) async {
        _ = try? await SupabaseProvider.client
            .from("user_state")
            .upsert(ProfileUpdate(
                user_id: userID,
                first_name: firstName,
                last_name: lastName,
                gender: gender.rawValue
            ))
            .execute()
    }

    func toggleFavorite(userID: String, quoteID: String, isFavorite: Bool) async {
        do {
            if isFavorite {
                try await SupabaseProvider.client
                    .from("favorites")
                    .insert(["user_id": userID, "quote_id": quoteID])
                    .execute()
            } else {
                try await SupabaseProvider.client
                    .from("favorites")
                    .delete()
                    .eq("user_id", value: userID)
                    .eq("quote_id", value: quoteID)
                    .execute()
            }
        } catch {
            // The optimistic local write already happened; the next sync-on-launch will retry.
        }
    }

    /// `nil` quand la requête échoue — hors ligne, l'appelant doit conserver ce qu'il a en
    /// local plutôt que de le remplacer par une liste vide.
    private func fetchFavorites(userID: String) async -> Set<String>? {
        do {
            let rows: [RemoteFavorite] = try await SupabaseProvider.client
                .from("favorites")
                .select("quote_id")
                .eq("user_id", value: userID)
                .execute()
                .value
            return Set(rows.map(\.quote_id))
        } catch {
            return nil
        }
    }

    private func reconcileStreak(userID: String) async -> (streak: Int?, profile: Profile, grantedPremium: Bool?) {
        let today = Calendar.current.startOfDay(for: Date())

        // Volontairement `limit(1)` et non `single()` : `single()` lève aussi bien quand la
        // ligne n'existe pas encore (compte tout neuf) que quand le réseau est coupé. Les
        // deux cas étaient donc traités comme « aucune donnée », et une ouverture hors
        // ligne remettait la série à 1 — y compris à l'écran et dans les préférences.
        let remote: RemoteUserState?
        do {
            let rows: [RemoteUserState] = try await SupabaseProvider.client
                .from("user_state")
                .select()
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            remote = rows.first
        } catch {
            // Requête impossible : on ne touche à rien côté serveur et on laisse
            // l'appelant garder son état local.
            return (nil, Profile(), nil)
        }

        // L'état des jokers vient du serveur avant toute décision : sur un téléphone
        // fraîchement installé, le local est vide et on offrirait un quota neuf à
        // quelqu'un qui a déjà dépensé le sien ce mois-ci.
        applyRemoteFreezeState(remote)

        // `StreakManager.resolve` écrit lui-même le joker consommé (compteur et jour
        // gelé) : il n'y a rien à récupérer ici en dehors de la série.
        var newStreak = 1
        if let lastOpenString = remote?.last_open_date, let lastOpen = Self.dateFormatter.date(from: lastOpenString) {
            let daysSince = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: lastOpen),
                to: today
            ).day ?? 0

            let resolution = StreakManager.resolve(
                daysSince: daysSince,
                previousStreak: remote?.streak_count ?? 0,
                today: today,
                isPremium: Self.isPremiumForFreezes(remote)
            )
            newStreak = resolution.streak
        } else {
            // Première ouverture connue : on amorce quand même le quota du mois.
            StreakFreeze.refillIfNeeded(isPremium: Self.isPremiumForFreezes(remote), on: today)
        }

        let updated = StreakUpdate(
            user_id: userID,
            streak_count: newStreak,
            last_open_date: Self.dateFormatter.string(from: today),
            freezes_remaining: SharedDefaults.freezesRemaining,
            freeze_period: SharedDefaults.freezePeriod,
            freeze_granted: SharedDefaults.freezeGranted,
            last_freeze_date: SharedDefaults.lastFreezeDate.map(Self.dateFormatter.string(from:))
        )
        // Best-effort: the streak is returned locally even if the write fails.
        _ = try? await SupabaseProvider.client
            .from("user_state")
            .upsert(updated)
            .execute()

        let profile = Profile(
            firstName: remote?.first_name,
            lastName: remote?.last_name,
            gender: remote?.gender.flatMap(Gender.init(rawValue:))
        )
        return (newStreak, profile, Self.isGrantActive(remote))
    }

    /// Recopie l'état des jokers renvoyé par le serveur, quand il en a un.
    ///
    /// Le jour gelé est réinjecté dans l'historique local : c'est ce qui permet à la
    /// semaine de montrer un flocon plutôt qu'un trou après un changement d'appareil.
    private func applyRemoteFreezeState(_ remote: RemoteUserState?) {
        guard let remote, let period = remote.freeze_period else { return }
        SharedDefaults.freezePeriod = period
        SharedDefaults.freezesRemaining = remote.freezes_remaining ?? 0
        SharedDefaults.freezeGranted = remote.freeze_granted ?? 0
        if let lastFreeze = remote.last_freeze_date.flatMap(Self.dateFormatter.date(from:)) {
            SharedDefaults.lastFreezeDate = lastFreeze
            var frozen = SharedDefaults.frozenDays
            frozen.insert(SharedDefaults.dayKey(for: lastFreeze))
            SharedDefaults.frozenDays = frozen
        }
    }

    /// Premium tel qu'on peut le connaître à cet instant : `StoreManager.refresh()` ne
    /// tourne qu'après cette synchronisation, on se contente donc de la dernière valeur
    /// connue et du cadeau que le serveur vient de renvoyer. Se tromper ne coûte au pire
    /// que deux jokers de retard, comblés au passage suivant par `refillIfNeeded`.
    private static func isPremiumForFreezes(_ remote: RemoteUserState?) -> Bool {
        SharedDefaults.isPremium || isGrantActive(remote)
    }

    /// Un cadeau n'est actif que s'il est marqué comme tel et qu'il n'a pas expiré.
    /// `premium_until` nul vaut « sans limite de durée ».
    private static func isGrantActive(_ remote: RemoteUserState?) -> Bool {
        guard remote?.premium_granted == true else { return false }
        guard let until = remote?.premium_until else { return true }
        guard let expiry = parseTimestamp(until) else {
            // Date illisible : on préfère laisser l'accès plutôt que de le couper à tort.
            return true
        }
        return expiry > Date()
    }

    /// PostgREST renvoie les `timestamptz` avec ou sans fractions de seconde selon la
    /// valeur stockée, et un `ISO8601DateFormatter` n'accepte que l'une des deux formes.
    private static func parseTimestamp(_ value: String) -> Date? {
        for formatter in [Self.iso8601WithFraction, Self.iso8601] {
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static let iso8601WithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601 = ISO8601DateFormatter()
}
