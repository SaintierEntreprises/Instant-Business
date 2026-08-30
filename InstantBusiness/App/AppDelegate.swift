import UIKit
import UserNotifications

/// Existe uniquement pour recevoir les appuis sur les notifications.
///
/// Sans délégué `UNUserNotificationCenter`, iOS se contente d'ouvrir l'app : la citation
/// affichée dans la notification était donc perdue, et on atterrissait sur un fil
/// mélangé sans rapport. Le délégué doit être posé avant la fin du lancement pour que la
/// réponse qui a réveillé l'app soit bien délivrée, d'où l'`AppDelegate` plutôt qu'un
/// `onAppear` côté SwiftUI.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Appui sur une notification, app lancée ou non.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let quoteID = userInfo[NotificationPayload.quoteIDKey] as? String
        let kind = userInfo[NotificationPayload.kindKey] as? String
        Task { @MainActor in
            Analytics.track(.notificationOpened, [
                "quote_id": .string(quoteID ?? "none"),
                "kind": .string(kind ?? "quote"),
                "identifier": .string(response.notification.request.identifier)
            ])
            AppRouter.shared.launchSource = .notification
            if let quoteID { AppRouter.shared.pendingQuoteID = quoteID }
            if kind == NotificationPayload.streakKind {
                AppRouter.shared.pendingStreakCelebration = true
            }
        }
        completionHandler()
    }

    /// Sans cela, une notification arrivant pendant que l'app est ouverte est avalée en
    /// silence : rien ne s'affiche, et il n'y a donc rien sur quoi appuyer.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Notifications push

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushRegistrar.store(deviceToken: deviceToken) }
    }

    /// Échec silencieux volontaire : sans réseau, ou sur un simulateur qui ne sait pas
    /// délivrer de jeton, il n'y a rien à faire et rien à dire à l'utilisateur — le push
    /// est un complément, les notifications programmées localement continuent seules.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {}
}

enum NotificationPayload {
    /// Clé de l'identifiant de citation transporté par chaque notification.
    static let quoteIDKey = "quoteID"

    /// Nature de la notification, quand elle n'est pas une simple citation.
    static let kindKey = "kind"

    /// Rappel « ne perds pas ta série ». Marqué pour que l'appui ouvre directement le
    /// suivi de série : sans ce marqueur, la notification qui parle de la série menait à
    /// un fil de citations où rien n'y répondait.
    static let streakKind = "streak"
}
