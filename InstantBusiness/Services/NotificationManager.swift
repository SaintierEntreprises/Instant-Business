import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    private static let dailyIdentifierPrefix = "instant-business-daily-"
    private static let rotationIdentifierPrefix = "instant-business-rotation-"

    /// Fenêtre glissante de programmation.
    ///
    /// iOS plafonne à 64 les notifications locales en attente. Au rythme le plus dense
    /// (6 par jour), dix jours en consommeraient 60, plus les deux rappels de série :
    /// trop juste si le plafond était atteint, la fin de la fenêtre serait silencieusement
    /// tronquée. La fenêtre s'adapte donc au rythme choisi pour rester sous la limite dans
    /// tous les cas.
    private var rollingWindowDays: Int {
        let perDay = max(1, SharedDefaults.notificationFrequency.perDay)
        return min(14, max(3, 55 / perDay))
    }

    private static let streakReminderIdentifier = "instant-business-streak"
    private static let streakLostIdentifier = "instant-business-streak-lost"
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
        PreferenceSync.push()
        await reschedule()
    }

    func disable() {
        SharedDefaults.notificationsEnabled = false
        PreferenceSync.push()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Réglage distant en vigueur, reconstruit depuis la copie locale.
    nonisolated static var remoteConfig: NotificationConfig {
        let stored = SharedDefaults.notificationConfig
        return NotificationConfig.from(
            enabled: stored["enabled"] as? Bool,
            dailyQuoteMode: stored["dailyQuoteMode"] as? String,
            hours: stored["hours"] as? [String: [Int]]
        )
    }

    func reschedule() async {
        guard SharedDefaults.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        // Interrupteur d'urgence : ne rien envoyer vaut mieux qu'envoyer n'importe quoi,
        // le temps qu'un correctif atteigne les téléphones. Placé après l'effacement, pour
        // que l'actionner retire aussi ce qui était déjà programmé.
        let config = Self.remoteConfig
        guard config.allowsScheduling else { return }

        let calendar = Calendar.current
        let now = Date()
        let seed = SharedDefaults.rotationSeed

        // Créneaux fixes issus du rythme choisi, jamais ancrés sur « maintenant » : le
        // faire repousserait la prochaine notification à chaque ouverture de l'app, si
        // bien que plus quelqu'un s'en sert, moins il en recevrait.
        let hours = config.hours(for: SharedDefaults.notificationFrequency)
        let days = rollingWindowDays

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            for slot in Self.slots(for: day, hours: hours, now: now, calendar: calendar) {
                if slot.carriesDailyQuote, config.usesDailyQuote {
                    guard let quote = ContentStore.quoteOfTheDay(on: day) else { continue }
                    await schedule(
                        identifier: Self.dailyIdentifierPrefix + "\(offset)",
                        title: "Citation du jour",
                        quote: quote,
                        fireDate: slot.fireDate,
                        center: center
                    )
                } else {
                    // Les deux tirages sont indépendants : rien n'empêche la rotation de
                    // retomber sur la citation du jour, et recevoir deux fois la même dans
                    // la journée se remarque immédiatement. On avance alors d'un cran.
                    let unit = ContentStore.rotationUnit(for: slot.fireDate)
                    let daily = ContentStore.quoteOfTheDay(on: day)
                    guard var quote = ContentStore.rotatingQuote(seed: seed, unit: unit) else { continue }
                    if quote.id == daily?.id,
                       let next = ContentStore.rotatingQuote(seed: seed, unit: unit + 1) {
                        quote = next
                    }
                    await schedule(
                        identifier: Self.rotationIdentifierPrefix + "\(offset)-\(slot.hour)",
                        title: "Instant Business",
                        quote: quote,
                        fireDate: slot.fireDate,
                        center: center
                    )
                }
            }
        }

        await scheduleStreakReminder(now: now, calendar: calendar, center: center)
    }

    /// Créneaux encore programmables pour une journée, et celui qui portera la citation
    /// du jour.
    ///
    /// La citation du jour appartient au **premier créneau du rythme choisi**, et non au
    /// premier créneau encore à venir. La nuance est tout le sujet : `reschedule()`
    /// s'exécute à chaque passage au premier plan et reconstruit toutes les notifications
    /// en attente. Désigner « le prochain créneau libre » rendait donc l'attribution
    /// dépendante de l'heure d'exécution — la citation du jour partait à 9 h, puis l'app
    /// rouverte à 10 h la réattribuait à 14 h, puis à 20 h. La même citation arrivait
    /// trois fois dans la journée.
    ///
    /// Ancrée sur le premier horaire configuré, l'attribution ne dépend plus que du jour
    /// et du rythme : reprogrammer à n'importe quelle heure donne le même résultat.
    ///
    /// Conséquence assumée : activer les notifications après le premier horaire ne donne
    /// pas la citation du jour ce jour-là. Elle reste lisible dans l'app et sur le widget,
    /// et une attribution stable vaut mieux qu'un doublon quotidien.
    ///
    /// Fonction pure, statique et `nonisolated` pour être testable : elle ne touche à
    /// aucun état, et le cas ne se reproduit à la main qu'en changeant l'heure du
    /// téléphone.
    nonisolated static func slots(
        for day: Date,
        hours: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> [(hour: Int, fireDate: Date, carriesDailyQuote: Bool)] {
        let sorted = hours.sorted()
        var result: [(hour: Int, fireDate: Date, carriesDailyQuote: Bool)] = []
        for hour in sorted {
            guard let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  fireDate > now else { continue }
            result.append((hour, fireDate, hour == sorted.first))
        }
        return result
    }

    /// Deux rappels de série à 18h : le lendemain du dernier jour d'ouverture, puis le
    /// surlendemain.
    ///
    /// Une notification locale ne peut pas décider au dernier moment si elle doit
    /// s'afficher : elle est programmée à l'avance. Le filtrage se fait donc à l'envers —
    /// `reschedule()` efface tout et reprogramme à chaque passage au premier plan, si
    /// bien qu'ouvrir l'app supprime mécaniquement les rappels en attente. Ils ne
    /// survivent que si personne n'ouvre l'app d'ici là, ce qui est exactement la
    /// condition voulue.
    ///
    /// Les deux jours ne disent pas la même chose, et ce n'est pas un détail de ton :
    /// rater une seule journée remet déjà la série à 1 (voir le `default` de
    /// `UserSyncService.reconcileStreak`). Au premier jour la série est encore là et il
    /// s'agit de la garder ; au second elle est perdue, et annoncer « ne perds pas ta
    /// série de 6 jours » y serait faux. Le second rappel existe parce que sans lui,
    /// quelqu'un qui saute deux jours ne recevait plus jamais un mot au sujet de sa
    /// série — le rappel du lendemain était déjà passé, et rien ne le remplaçait.
    private func scheduleStreakReminder(now: Date, calendar: Calendar, center: UNUserNotificationCenter) async {
        let streak = SharedDefaults.streakCount
        guard streak > 0 else { return }

        let lastOpen = calendar.startOfDay(for: SharedDefaults.lastForegroundDate ?? now)
        let name = SharedDefaults.firstName.flatMap { $0.isEmpty ? nil : $0 }

        // Jour 1 : la série tient encore. Quand ce jour-là fait justement franchir un
        // palier, on l'annonce plutôt que de répéter la menace : un rappel qui promet
        // quelque chose se lit autrement qu'un rappel qui met en garde, et c'est le seul
        // soir de la série où on a une bonne nouvelle à donner d'avance.
        let nextMilestone = StreakBadge.badge(for: streak + 1)
        await scheduleStreakNotification(
            identifier: Self.streakReminderIdentifier,
            dayOffset: 1,
            title: nextMilestone.map { "À un jour du palier de \($0.days) jours" }
                ?? "Ne perds pas ta série de \(streak) jour\(streak > 1 ? "s" : "")",
            body: {
                if let nextMilestone {
                    return name.map { "\($0), ouvre Instant Business aujourd'hui et le palier « \(nextMilestone.name) » est à toi." }
                        ?? "Ouvre Instant Business aujourd'hui et le palier « \(nextMilestone.name) » est à toi."
                }
                return name.map { "\($0), tu n'as pas encore ouvert Instant Business aujourd'hui. Une citation suffit pour la garder." }
                    ?? "Tu n'as pas encore ouvert Instant Business aujourd'hui. Une citation suffit pour la garder."
            }(),
            lastOpen: lastOpen,
            now: now,
            calendar: calendar,
            center: center
        )

        // Jour 2 : la série est tombée, on propose d'en relancer une plutôt que de faire
        // comme si de rien n'était.
        await scheduleStreakNotification(
            identifier: Self.streakLostIdentifier,
            dayOffset: 2,
            title: "Ta série de \(streak) jour\(streak > 1 ? "s" : "") s'est arrêtée",
            body: SharedDefaults.freezesRemaining > 0
                ? "Il te reste un joker : ouvre l'app aujourd'hui et ta série repart d'où elle s'était arrêtée."
                : (name.map { "\($0), rien n'est perdu : une citation aujourd'hui et une nouvelle série démarre." }
                   ?? "Rien n'est perdu : une citation aujourd'hui et une nouvelle série démarre."),
            lastOpen: lastOpen,
            now: now,
            calendar: calendar,
            center: center
        )
    }

    private func scheduleStreakNotification(
        identifier: String,
        dayOffset: Int,
        title: String,
        body: String,
        lastOpen: Date,
        now: Date,
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) async {
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: lastOpen),
              let fireDate = calendar.date(bySettingHour: Self.streakReminderHour, minute: 0, second: 0, of: day),
              fireDate > now
        else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [NotificationPayload.kindKey: NotificationPayload.streakKind]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
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
