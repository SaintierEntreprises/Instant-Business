import Foundation

/// Joker de série : une journée manquée absorbée, sans que la série reparte de zéro.
///
/// La règle d'origine était la plus dure possible — un seul jour oublié renvoyait à 1,
/// effaçant d'un coup des semaines. Or c'est précisément le lendemain d'un oubli qu'on
/// abandonne : il n'y a plus rien à sauver. Le joker rend ce lendemain-là encore utile.
///
/// Volontairement rare et non cumulable d'un mois sur l'autre : un joker qui s'accumule
/// finit par rendre la série impossible à perdre, et une série qu'on ne peut pas perdre ne
/// veut plus rien dire.
enum StreakFreeze {
    /// Un par mois, trois pour les abonnés.
    static func allowance(isPremium: Bool) -> Int { isPremium ? 3 : 1 }

    static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static func period(for date: Date) -> String {
        periodFormatter.string(from: date)
    }

    /// Réapprovisionne au changement de mois, et complète si l'abonnement a été souscrit
    /// en cours de mois.
    ///
    /// `freezeGranted` retient le quota déjà accordé pour la période : sans lui, le
    /// complément premium se rejouerait à chaque passage au premier plan et les jokers se
    /// rechargeraient indéfiniment. Le complément ne rend jamais un joker déjà dépensé, et
    /// rien n'est repris quand l'abonnement expire — on redescend simplement au quota
    /// gratuit le mois suivant.
    @discardableResult
    static func refillIfNeeded(isPremium: Bool, on date: Date = Date()) -> Int {
        let period = period(for: date)
        let allowance = allowance(isPremium: isPremium)

        if SharedDefaults.freezePeriod != period {
            SharedDefaults.freezePeriod = period
            SharedDefaults.freezeGranted = allowance
            SharedDefaults.freezesRemaining = allowance
        } else if allowance > SharedDefaults.freezeGranted {
            let bonus = allowance - SharedDefaults.freezeGranted
            SharedDefaults.freezeGranted = allowance
            SharedDefaults.freezesRemaining += bonus
        }

        return SharedDefaults.freezesRemaining
    }

    static func hasFreezeAvailable() -> Bool {
        SharedDefaults.freezesRemaining > 0
    }

    /// Consomme un joker pour couvrir `day`. Retourne `false` s'il n'y en avait plus.
    @discardableResult
    static func consume(covering day: Date) -> Bool {
        guard SharedDefaults.freezesRemaining > 0 else { return false }
        SharedDefaults.freezesRemaining -= 1
        SharedDefaults.lastFreezeDate = day
        var frozen = SharedDefaults.frozenDays
        frozen.insert(SharedDefaults.dayKey(for: day))
        SharedDefaults.frozenDays = frozen
        return true
    }
}
