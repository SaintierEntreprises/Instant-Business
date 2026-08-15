import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    private static let dailyIdentifierPrefix = "instant-business-daily-"
    private static let rotationIdentifierPrefix = "instant-business-rotation-"

    /// Every 6h + 1 daily "citation du jour" = 5/day. iOS caps pending local notifications
    /// at 64, so a 10-day rolling window (50 requests) stays comfortably under that.
    private let rollingWindowDays = 10
    private let rotationIntervalHours = 6

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

    func enable() async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            SharedDefaults.notificationsEnabled = false
            return
        }
        SharedDefaults.notificationsEnabled = true
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

        let calendar = Calendar.current
        let now = Date()
        let seed = SharedDefaults.rotationSeed

        // Fixed for every user: the daily quote, sent at midnight.
        for offset in 0..<rollingWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: day),
                  fireDate > now,
                  let quote = ContentStore.quoteOfTheDay(on: day) else { continue }

            await schedule(
                identifier: Self.dailyIdentifierPrefix + "\(offset)",
                title: "Citation du jour",
                quote: quote,
                fireDate: fireDate,
                center: center
            )
        }

        // Per-user rotation, every 6h: same schedule the widget reads from, so a
        // notification always matches whatever is currently showing on the widget.
        var hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        hourComponents.minute = 0
        hourComponents.second = 0
        let currentHour = calendar.date(from: hourComponents) ?? now
        let totalSlots = (rollingWindowDays * 24) / rotationIntervalHours

        for slot in 0..<totalSlots {
            guard let fireDate = calendar.date(byAdding: .hour, value: slot * rotationIntervalHours, to: currentHour),
                  fireDate > now else { continue }
            let unit = ContentStore.hourSlot(for: fireDate)
            guard let quote = ContentStore.rotatingQuote(seed: seed, unit: unit) else { continue }

            await schedule(
                identifier: Self.rotationIdentifierPrefix + "\(slot)",
                title: "Instant Business",
                quote: quote,
                fireDate: fireDate,
                center: center
            )
        }
    }

    private func schedule(identifier: String, title: String, quote: Quote, fireDate: Date, center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(quote.text) — \(quote.author)"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
