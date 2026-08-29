import Foundation
import UIKit
import Supabase

/// Enregistrement de l'appareil auprès d'Apple, puis du jeton obtenu dans Supabase.
///
/// Complète — sans remplacer — les notifications programmées localement par
/// `NotificationManager`. Celles-ci partent du téléphone selon un calendrier fixe ;
/// le push, lui, part du serveur au moment choisi, ce qui suppose de savoir à quel
/// appareil s'adresser.
@MainActor
enum PushRegistrar {
    /// À appeler une fois l'autorisation de notification accordée. Sans autorisation,
    /// Apple délivre bien un jeton mais aucune alerte ne s'affichera, ce qui donnerait
    /// l'illusion d'un envoi réussi.
    static func registerIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    private struct TokenRow: Encodable {
        let token: String
        let user_id: String
        let environment: String
        let app_version: String
    }

    /// Appelé par l'`AppDelegate` quand Apple retourne le jeton de cet appareil.
    ///
    /// Le jeton change à la réinstallation, à la restauration d'une sauvegarde, et
    /// parfois sans raison apparente — d'où l'écriture à chaque lancement plutôt qu'une
    /// seule fois, avec un `upsert` qui ne crée pas de doublon.
    static func store(deviceToken: Data) {
        guard let userID = SupabaseProvider.client.auth.currentUser?.id.uuidString else { return }

        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let row = TokenRow(
            token: token,
            user_id: userID,
            environment: Self.environment,
            app_version: AppUpdateGate.installedVersion
        )

        Task.detached {
            _ = try? await SupabaseProvider.client
                .from("device_tokens")
                .upsert(row)
                .execute()
        }
    }

    /// Apple sert deux réseaux distincts et rejette un jeton présenté au mauvais.
    ///
    /// Ce qui décide, c'est le profil d'approvisionnement — pas le type de build.
    /// TestFlight et l'App Store utilisent tous deux un profil de distribution, donc
    /// tous deux parlent à la production. Seul un lancement direct depuis Xcode (profil
    /// de développement) parle au bac à sable.
    ///
    /// Une version antérieure se fiait au nom du reçu (« sandboxReceipt » pour
    /// TestFlight) en le confondant avec l'environnement push : ce nom concerne les
    /// achats, pas les notifications, et aurait classé chaque testeur TestFlight au
    /// mauvais réseau — leurs jetons se seraient vus opposer un rejet silencieux à
    /// chaque tentative d'envoi.
    private static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
