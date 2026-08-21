import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    private static let dailyIdentifierPrefix = "instant-business-daily-"
    private static let rotationIdentifierPrefix = "instant-business-rotation-"

    /// Fixed times of day for the rotating quote. With the daily quote at midnight,
    /// this yields one notification every 4 hours: 00h, 04h, 08h, 12h, 16h, 20h.
    private static let rotationHours = [4, 8, 12, 16, 20]

    /// 6 notifications/day (1 daily + 5 rotation). iOS caps pending local notifications
    /// at 64, so a 10-day rolling window (60 requests) stays under that.
    private let rollingWindowDays = 10

    /// Autorisation réellement accordée au niveau du système, sans jamais présenter de
    /// demande — contrairement à `requestAuthorizationIfNeeded`, qui en déclenche une.
    func isSystemAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

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

        // Per-user rotation at fixed times of day, so the schedule never shifts.
        // Anchoring on "now" instead would push the next notification 4h away every
        // time the app is opened — the more someone uses the app, the fewer they'd get.
        // Combined with the midnight daily quote, this lands one notification every 4h.
        for offset in 0..<rollingWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            for hour in Self.rotationHours {
                guard let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                      fireDate > now else { continue }
                let unit = ContentStore.hourSlot(for: fireDate)
                guard let quote = ContentStore.rotatingQuote(seed: seed, unit: unit) else { continue }

                await schedule(
                    identifier: Self.rotationIdentifierPrefix + "\(offset)-\(hour)",
                    title: "Instant Business",
                    quote: quote,
                    fireDate: fireDate,
                    center: center
                )
            }
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
