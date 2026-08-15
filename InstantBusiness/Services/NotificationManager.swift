import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    private static let identifierPrefix = "instant-business-daily-"
    private let rollingWindowDays = 14

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    func enable(hour: Int, minute: Int) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            SharedDefaults.notificationsEnabled = false
            return
        }
        SharedDefaults.notificationsEnabled = true
        SharedDefaults.notificationHour = hour
        SharedDefaults.notificationMinute = minute
        await reschedule()
    }

    func disable() {
        SharedDefaults.notificationsEnabled = false
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func reschedule() async {
        guard SharedDefaults.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let hour = SharedDefaults.notificationHour
        let minute = SharedDefaults.notificationMinute
        let calendar = Calendar.current

        for offset in 0..<rollingWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > Date(),
                  let quote = ContentStore.quoteOfTheDay(on: day) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Citation du jour"
            content.body = "\(quote.text) — \(quote.author)"
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + "\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
