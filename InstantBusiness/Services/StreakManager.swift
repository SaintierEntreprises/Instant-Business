import Foundation

enum StreakManager {
    /// Issue d'une ouverture, une fois la règle de série appliquée.
    struct Resolution {
        var streak: Int
        /// Jour manqué couvert par un joker, quand il y en a eu un.
        var frozenDay: Date?
    }

    /// Règle de série, en un seul endroit.
    ///
    /// Elle était écrite deux fois — ici pour le mode hors ligne, et dans
    /// `UserSyncService.reconcileStreak` pour le mode connecté. Les deux devaient déjà
    /// rester d'accord ; avec les jokers, qui décident de conserver ou non des semaines
    /// de série, une divergence deviendrait un bug qu'on ne verrait qu'en production.
    ///
    /// - Parameter daysSince: jours écoulés depuis la dernière ouverture. 0 = déjà ouvert
    ///   aujourd'hui, 1 = hier, 2 = une seule journée manquée.
    static func resolve(
        daysSince: Int,
        previousStreak: Int,
        today: Date,
        calendar: Calendar = .current,
        isPremium: Bool
    ) -> Resolution {
        StreakFreeze.refillIfNeeded(isPremium: isPremium, on: today)

        /// La série repart de 1, et avec elle les paliers à refêter.
        ///
        /// Sans cette remise à zéro, quelqu'un qui perd une série de 30 jours ne reverrait
        /// plus jamais de célébration avant le 60e — soit au moment précis où il aurait le
        /// plus besoin qu'on lui dise qu'il avance.
        func restart() -> Resolution {
            SharedDefaults.celebratedMilestone = 0
            return Resolution(streak: 1, frozenDay: nil)
        }

        switch daysSince {
        case 0:
            return Resolution(streak: max(previousStreak, 1), frozenDay: nil)
        case 1:
            return Resolution(streak: previousStreak + 1, frozenDay: nil)
        case 2:
            // Exactement une journée manquée : la seule que le joker sait couvrir. Au-delà
            // il faudrait en dépenser plusieurs d'un coup, et une série qu'on rattrape
            // après une semaine d'absence ne veut plus dire grand-chose.
            guard previousStreak > 0,
                  let missed = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today)),
                  StreakFreeze.consume(covering: missed)
            else {
                return restart()
            }
            return Resolution(streak: previousStreak + 1, frozenDay: missed)
        default:
            return restart()
        }
    }

    @discardableResult
    static func recordOpenToday() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastOpen = SharedDefaults.lastOpenDate else {
            SharedDefaults.streakCount = 1
            SharedDefaults.lastOpenDate = today
            return 1
        }

        let lastOpenDay = calendar.startOfDay(for: lastOpen)
        let daysSince = calendar.dateComponents([.day], from: lastOpenDay, to: today).day ?? 0
        guard daysSince != 0 else { return SharedDefaults.streakCount }

        let resolution = resolve(
            daysSince: daysSince,
            previousStreak: SharedDefaults.streakCount,
            today: today,
            calendar: calendar,
            isPremium: SharedDefaults.isPremium
        )
        SharedDefaults.streakCount = resolution.streak
        SharedDefaults.lastOpenDate = today
        return resolution.streak
    }

    /// Inscrit le jour en cours dans l'historique local et le complète à rebours à partir
    /// de la série connue.
    ///
    /// Le remplissage rétroactif n'est pas cosmétique : l'historique est local et récent,
    /// alors que la série vient du serveur et peut valoir 40 sur un téléphone qu'on vient
    /// d'installer. Sans lui, quelqu'un qui change d'appareil verrait une semaine vide
    /// sous un compteur à 40. Une série de N jours qui inclut aujourd'hui signifie par
    /// définition que les N derniers jours ont été ouverts : on peut donc les reconstituer
    /// sans rien inventer.
    ///
    /// Idempotent — c'est un ensemble, réécrire un jour déjà présent ne change rien.
    static func recordVisit(streak: Int, on date: Date = Date(), calendar: Calendar = .current) {
        var days = SharedDefaults.openDays
        let today = calendar.startOfDay(for: date)
        days.insert(SharedDefaults.dayKey(for: today))

        if streak > 1 {
            let frozen = SharedDefaults.frozenDays
            for offset in 1..<min(streak, SharedDefaults.openDaysLimitForBackfill) {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
                let key = SharedDefaults.dayKey(for: day)
                // Un jour gelé appartient à la série sans avoir été ouvert : le
                // reconstituer comme ouvert prétendrait que la personne était là.
                guard !frozen.contains(key) else { continue }
                days.insert(key)
            }
        }
        SharedDefaults.openDays = days

        if streak > SharedDefaults.bestStreak {
            SharedDefaults.bestStreak = streak
        }
    }
}
