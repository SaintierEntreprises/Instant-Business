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
        let quoteID = response.notification.request.content.userInfo[NotificationPayload.quoteIDKey] as? String
        Task { @MainActor in
            Analytics.track(.notificationOpened, [
                "quote_id": .string(quoteID ?? "none"),
                "identifier": .string(response.notification.request.identifier)
            ])
            AppRouter.shared.launchSource = .notification
            if let quoteID { AppRouter.shared.pendingQuoteID = quoteID }
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
}

enum NotificationPayload {
    /// Clé de l'identifiant de citation transporté par chaque notification.
    static let quoteIDKey = "quoteID"
}
