import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    private static let dailyIdentifierPrefix = "instant-business-daily-"
    private static let rotationIdentifierPrefix = "instant-business-rotation-"

    /// Fenêtre glissante de programmation.
    ///
    /// iOS plafonne à 64 les notifications locales en attente. Au rythme le plus dense
    /// (6 par jour), dix jours en consommeraient 60, plus le rappel de série : trop juste
    /// si le plafond était atteint, la fin de la fenêtre serait silencieusement tronquée.
    /// La fenêtre s'adapte donc au rythme choisi pour rester sous la limite dans tous
    /// les cas.
    private var rollingWindowDays: Int {
        let perDay = max(1, SharedDefaults.notificationFrequency.perDay)
        return min(14, max(3, 55 / perDay))
    }

    private static let streakReminderIdentifier = "instant-business-streak"
    private static let streakReminderHour = 18

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

        // Créneaux fixes issus du rythme choisi, jamais ancrés sur « maintenant » : le
        // faire repousserait la prochaine notification à chaque ouverture de l'app, si
        // bien que plus quelqu'un s'en sert, moins il en recevrait.
        let hours = SharedDefaults.notificationFrequency.hours
        let days = rollingWindowDays

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            for (index, hour) in hours.enumerated() {
                guard let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                      fireDate > now else { continue }

                // La première notification de la journée porte la citation du jour, celle
                // que tout le monde reçoit ; les suivantes suivent la rotation propre à
                // chaque installation.
                if index == 0 {
                    guard let quote = ContentStore.quoteOfTheDay(on: day) else { continue }
                    await schedule(
                        identifier: Self.dailyIdentifierPrefix + "\(offset)",
                        title: "Citation du jour",
                        quote: quote,
                        fireDate: fireDate,
                        center: center
                    )
                } else {
                    let unit = ContentStore.rotationUnit(for: fireDate)
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

        await scheduleStreakReminder(now: now, calendar: calendar, center: center)
    }

    /// Rappel de série, à 18h, uniquement le lendemain du dernier jour d'ouverture.
    ///
    /// Une notification locale ne peut pas décider au dernier moment si elle doit
    /// s'afficher : elle est programmée à l'avance. Le filtrage se fait donc à l'envers —
    /// `reschedule()` efface tout et reprogramme à chaque passage au premier plan, si
    /// bien qu'ouvrir l'app supprime mécaniquement le rappel du jour. Il ne survit que
    /// si personne n'ouvre l'app d'ici là, ce qui est exactement la condition voulue.
    ///
    /// Un seul jour est programmé, et c'est volontaire : rater une seule journée remet
    /// déjà la série à 1 (voir le `default` de `UserSyncService.reconcileStreak`).
    /// Le surlendemain, la série est perdue — annoncer « ne perds pas ta série de 6
    /// jours » y serait faux.
    private func scheduleStreakReminder(now: Date, calendar: Calendar, center: UNUserNotificationCenter) async {
        let streak = SharedDefaults.streakCount
        guard streak > 0 else { return }

        let lastOpen = SharedDefaults.lastForegroundDate ?? now
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastOpen)),
              let fireDate = calendar.date(bySettingHour: Self.streakReminderHour, minute: 0, second: 0, of: nextDay),
              fireDate > now
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ne perds pas ta série de \(streak) jour\(streak > 1 ? "s" : "")"
        if let firstName = SharedDefaults.firstName, !firstName.isEmpty {
            content.body = "\(firstName), tu n'as pas encore ouvert Instant Business aujourd'hui. Une citation suffit pour la garder."
        } else {
            content.body = "Tu n'as pas encore ouvert Instant Business aujourd'hui. Une citation suffit pour la garder."
        }
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: Self.streakReminderIdentifier, content: content, trigger: trigger)
        )
    }

    private func schedule(identifier: String, title: String, quote: Quote, fireDate: Date, center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(quote.text) — \(quote.author)"
        content.sound = .default
        // Sans cet identifiant, appuyer sur la notification ouvrait l'app sur un fil
        // mélangé, sans la citation qu'on venait de lire.
        content.userInfo = [NotificationPayload.quoteIDKey: quote.id]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
