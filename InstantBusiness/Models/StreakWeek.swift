import Foundation

/// Un jour de la semaine affichée, déjà résolu pour la vue.
///
/// La vue ne recalcule rien : elle reçoit sept états prêts à dessiner. Le tracker apparaît
/// à deux endroits (la célébration et les réglages) et les deux doivent dire exactement la
/// même chose — dupliquer le calcul serait le moyen le plus sûr qu'ils divergent.
struct StreakDay: Identifiable, Equatable {
    let date: Date
    /// Initiale affichée sous le rond. Volontairement figée plutôt que dérivée d'un
    /// formateur : la locale de l'appareil peut être l'anglais alors que l'app est en
    /// français, et on obtiendrait alors « M T W T F S S ».
    let initial: String
    /// Nom complet, réservé à VoiceOver — l'initiale seule y serait illisible, et deux
    /// jours partagent la même (mardi, mercredi).
    let fullName: String
    let isOpened: Bool
    /// Journée manquée mais couverte par un joker. Exclusif de `isOpened` à l'affichage :
    /// dire « fait » d'un jour gelé serait un mensonge, l'effacer serait injuste.
    let isFrozen: Bool
    /// Compté dans la série *et* rattaché à la série en cours. Un jour ouvert avant une coupure reste
    /// marqué, mais sans la flamme : il compte comme fait, pas comme acquis.
    let isInCurrentStreak: Bool
    let isToday: Bool
    let isFuture: Bool

    var id: Date { date }
}

enum StreakWeek {
    /// Semaine du lundi au dimanche, quelle que soit la région de l'appareil.
    ///
    /// `Calendar.current` commence le dimanche dans plusieurs régions, dont les
    /// États-Unis : la grille se décalerait d'un jour selon les réglages du téléphone,
    /// pour une app qui n'existe qu'en français.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    private static let initials = ["L", "M", "M", "J", "V", "S", "D"]
    private static let names = [
        "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"
    ]

    static func days(
        streak: Int,
        openDays: Set<String>,
        frozenDays: Set<String> = [],
        reference: Date = Date()
    ) -> [StreakDay] {
        let calendar = calendar
        let today = calendar.startOfDay(for: reference)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        func counts(_ date: Date) -> Bool {
            let key = SharedDefaults.dayKey(for: date)
            return openDays.contains(key) || frozenDays.contains(key)
        }

        // La série se rattache au dernier jour qu'elle compte. L'ancrer sur aujourd'hui
        // sans vérifier décalerait tout d'un cran le matin où l'app n'a pas encore été
        // ouverte — le dernier jour de la série serait alors compté comme manqué.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let anchor: Date?
        if counts(today) {
            anchor = today
        } else if let yesterday, counts(yesterday) {
            anchor = yesterday
        } else {
            anchor = nil
        }

        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: weekStart) else { return nil }
            let key = SharedDefaults.dayKey(for: date)
            let isOpened = openDays.contains(key)
            let isFrozen = !isOpened && frozenDays.contains(key)
            var isInCurrentStreak = false
            if isOpened || isFrozen, streak > 0, let anchor, date <= anchor {
                let distance = calendar.dateComponents([.day], from: date, to: anchor).day ?? .max
                isInCurrentStreak = distance < streak
            }

            return StreakDay(
                date: date,
                initial: initials[index],
                fullName: names[index],
                isOpened: isOpened,
                isFrozen: isFrozen,
                isInCurrentStreak: isInCurrentStreak,
                isToday: date == today,
                isFuture: date > today
            )
        }
    }
}

extension StreakWeek {
    /// Mois complet, en cases alignées sur une grille lundi → dimanche.
    ///
    /// `nil` marque les cases de remplissage avant le 1er et après le dernier jour : sans
    /// elles, le 1er du mois se poserait sous « L » quel que soit le vrai jour de la
    /// semaine, et tout le calendrier mentirait.
    ///
    /// `initial` porte ici le numéro du jour plutôt qu'une lettre — c'est ce qu'on lit
    /// dans un calendrier, et ça évite un second modèle presque identique.
    static func month(
        containing date: Date,
        streak: Int,
        openDays: Set<String>,
        frozenDays: Set<String> = [],
        reference: Date = Date()
    ) -> [StreakDay?] {
        let calendar = calendar
        let today = calendar.startOfDay(for: reference)
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayCount = calendar.range(of: .day, in: .month, for: date)?.count
        else { return [] }

        let firstDay = interval.start
        // `weekday` compte à partir de dimanche = 1 ; on le ramène à lundi = 0.
        let leading = (calendar.component(.weekday, from: firstDay) + 5) % 7

        let anchorInfo = anchorDistanceBase(openDays: openDays, frozenDays: frozenDays, today: today, calendar: calendar)

        var cells: [StreakDay?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            let key = SharedDefaults.dayKey(for: day)
            let isOpened = openDays.contains(key)
            let isFrozen = !isOpened && frozenDays.contains(key)
            var isInCurrentStreak = false
            if isOpened || isFrozen, streak > 0, let anchor = anchorInfo, day <= anchor {
                let distance = calendar.dateComponents([.day], from: day, to: anchor).day ?? .max
                isInCurrentStreak = distance < streak
            }
            cells.append(
                StreakDay(
                    date: day,
                    initial: "\(calendar.component(.day, from: day))",
                    fullName: day.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                    isOpened: isOpened,
                    isFrozen: isFrozen,
                    isInCurrentStreak: isInCurrentStreak,
                    isToday: day == today,
                    isFuture: day > today
                )
            )
        }

        // Complète la dernière ligne, pour que la grille garde sept colonnes pleines.
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// Dernier jour compté par la série en cours, partagé par la semaine et le mois.
    private static func anchorDistanceBase(
        openDays: Set<String>,
        frozenDays: Set<String>,
        today: Date,
        calendar: Calendar
    ) -> Date? {
        func counts(_ date: Date) -> Bool {
            let key = SharedDefaults.dayKey(for: date)
            return openDays.contains(key) || frozenDays.contains(key)
        }
        if counts(today) { return today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), counts(yesterday) {
            return yesterday
        }
        return nil
    }

    /// Premier jour dont on garde une trace, pour borner la navigation du calendrier.
    static func earliestRecordedDay(openDays: Set<String>, frozenDays: Set<String> = []) -> Date? {
        guard let first = openDays.union(frozenDays).min() else { return nil }
        return dayKeyFormatterDate(first)
    }

    private static func dayKeyFormatterDate(_ key: String) -> Date? {
        SharedDefaults.dayKeyFormatter.date(from: key)
    }
}

/// Paliers de série, utilisés pour la barre de progression.
///
/// Un compteur qui monte sans fin n'annonce jamais rien : le palier suivant donne une
/// cible atteignable, et une barre qui avance chaque jour plutôt qu'un nombre nu.
enum StreakMilestone {
    static let ladder = [3, 7, 14, 30, 60, 100, 180, 365]

    static func next(after streak: Int) -> Int? {
        ladder.first { $0 > streak }
    }

    /// Palier précédent, ou 0 avant le premier : la barre part du dernier acquis, pas de
    /// zéro, sinon les sept derniers jours d'un palier à 30 paraissent n'avoir rien changé.
    static func previous(before milestone: Int) -> Int {
        ladder.last { $0 < milestone } ?? 0
    }

    /// Avancement vers le palier suivant, entre 0 et 1. `nil` quand tous sont franchis.
    static func progress(streak: Int) -> (next: Int, remaining: Int, fraction: Double)? {
        guard let next = next(after: streak) else { return nil }
        let floor = previous(before: next)
        let span = Double(next - floor)
        let done = Double(max(0, streak - floor))
        return (next, next - streak, span > 0 ? min(1, done / span) : 0)
    }
}
