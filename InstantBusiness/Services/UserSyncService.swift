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
        var gender: String?
    }

    /// Écritures volontairement séparées : chaque upsert ne transmet que ses propres
    /// colonnes, sinon la mise à jour du streak écraserait le prénom avec une valeur
    /// nulle (et inversement).
    private struct StreakUpdate: Encodable {
        let user_id: String
        var streak_count: Int
        var last_open_date: String?
    }

    private struct ProfileUpdate: Encodable {
        let user_id: String
        var first_name: String
        var gender: String
    }

    struct Profile {
        var firstName: String?
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
    func syncOnSignIn(userID: String) async -> (favoriteIDs: Set<String>, streak: Int, profile: Profile) {
        async let favorites = fetchFavorites(userID: userID)
        async let state = reconcileStreak(userID: userID)
        let resolved = await state
        return (await favorites, resolved.streak, resolved.profile)
    }

    func saveProfile(userID: String, firstName: String, gender: Gender) async {
        _ = try? await SupabaseProvider.client
            .from("user_state")
            .upsert(ProfileUpdate(user_id: userID, first_name: firstName, gender: gender.rawValue))
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

    private func fetchFavorites(userID: String) async -> Set<String> {
        do {
            let rows: [RemoteFavorite] = try await SupabaseProvider.client
                .from("favorites")
                .select("quote_id")
                .eq("user_id", value: userID)
                .execute()
                .value
            return Set(rows.map(\.quote_id))
        } catch {
            return []
        }
    }

    private func reconcileStreak(userID: String) async -> (streak: Int, profile: Profile) {
        let today = Calendar.current.startOfDay(for: Date())

        let remote: RemoteUserState? = try? await SupabaseProvider.client
            .from("user_state")
            .select()
            .eq("user_id", value: userID)
            .single()
            .execute()
            .value

        var newStreak = 1
        if let lastOpenString = remote?.last_open_date, let lastOpen = Self.dateFormatter.date(from: lastOpenString) {
            let daysSince = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: lastOpen),
                to: today
            ).day ?? 0

            switch daysSince {
            case 0: newStreak = remote?.streak_count ?? 1
            case 1: newStreak = (remote?.streak_count ?? 0) + 1
            default: newStreak = 1
            }
        }

        let updated = StreakUpdate(
            user_id: userID,
            streak_count: newStreak,
            last_open_date: Self.dateFormatter.string(from: today)
        )
        // Best-effort: the streak is returned locally even if the write fails.
        _ = try? await SupabaseProvider.client
            .from("user_state")
            .upsert(updated)
            .execute()

        let profile = Profile(
            firstName: remote?.first_name,
            gender: remote?.gender.flatMap(Gender.init(rawValue:))
        )
        return (newStreak, profile)
    }
}
