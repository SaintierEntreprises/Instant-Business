import Foundation
import Combine
import Supabase

/// Compare la version installée à la version minimale exigée, publiée dans Supabase.
///
/// Le mécanisme est présent mais inerte tant que `app_config.minimum_version` reste nul.
/// C'est l'intérêt de l'installer à l'avance : le jour où une version devra être rendue
/// obligatoire, elle le sera pour tous les téléphones qui portent déjà ce code, sans
/// avoir à attendre une nouvelle mise à jour — ce qui serait justement le problème.
@MainActor
final class AppUpdateGate: ObservableObject {
    /// Identifiant App Store de l'app, utilisé pour ouvrir sa fiche.
    ///
    /// `nonisolated` : c'est une constante, elle n'a aucune raison d'être liée au fil
    /// principal. Sans cela, la lire depuis un contexte non isolé — comme le lien « Noter
    /// l'app » — produit un avertissement qui devient une erreur en Swift 6.
    nonisolated static let appStoreID = "6801872138"

    nonisolated static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    @Published private(set) var isUpdateRequired = false
    @Published private(set) var requiredVersion: String?

    private struct RemoteConfig: Decodable {
        let minimum_version: String?
        let notifications_enabled: Bool?
        let daily_quote_mode: String?
        let notification_hours: [String: [Int]]?
    }

    /// Version marketing de l'app installée (« 1.1 »).
    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func refresh() async {
        let rows: [RemoteConfig]? = try? await SupabaseProvider.client
            .from("app_config")
            .select("minimum_version,notifications_enabled,daily_quote_mode,notification_hours")
            .limit(1)
            .execute()
            .value

        // Les réglages de notification voyagent dans la même requête : ils changent aussi
        // rarement que le minimum de version, et une requête de plus au lancement pour
        // n'apprendre presque jamais rien ne se justifie pas.
        if let row = rows?.first {
            Self.store(row)
        }

        // Toute incertitude laisse passer : réseau coupé, table absente, valeur illisible.
        // Bloquer une app par accident est bien pire que laisser tourner une version
        // périmée une journée de plus.
        guard let minimum = rows?.first?.minimum_version, !minimum.isEmpty else {
            isUpdateRequired = false
            requiredVersion = nil
            return
        }

        requiredVersion = minimum
        isUpdateRequired = Self.isVersion(Self.installedVersion, olderThan: minimum)
    }

    /// Recopie les réglages de notification, puis reprogramme si quelque chose a bougé.
    ///
    /// La reprogrammation n'a lieu qu'en cas de changement : elle efface et reconstruit
    /// toutes les notifications en attente, ce qu'il serait absurde de refaire à chaque
    /// lancement pour une valeur qui ne bouge que lors d'un incident.
    private static func store(_ row: RemoteConfig) {
        let updated: [String: Any] = [
            "enabled": row.notifications_enabled as Any,
            "dailyQuoteMode": row.daily_quote_mode as Any,
            "hours": row.notification_hours as Any
        ].compactMapValues { $0 is NSNull ? nil : $0 }

        let previous = SharedDefaults.notificationConfig
        SharedDefaults.notificationConfig = updated

        guard !NSDictionary(dictionary: previous).isEqual(to: updated) else { return }
        Task { await NotificationManager().reschedule() }
    }

    /// Comparaison composant par composant, en nombres : « 1.10 » est postérieure à
    /// « 1.9 », ce qu'une comparaison de chaînes conclurait à l'envers. Les longueurs
    /// différentes sont complétées par des zéros (« 1.1 » vaut « 1.1.0 »).
    static func isVersion(_ installed: String, olderThan required: String) -> Bool {
        let left = installed.split(separator: ".").map { Int($0) ?? 0 }
        let right = required.split(separator: ".").map { Int($0) ?? 0 }

        for index in 0..<max(left.count, right.count) {
            let lhs = index < left.count ? left[index] : 0
            let rhs = index < right.count ? right[index] : 0
            if lhs != rhs { return lhs < rhs }
        }
        return false
    }
}
