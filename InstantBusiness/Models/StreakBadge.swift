import SwiftUI

/// Insigne gagné en franchissant un palier de série.
///
/// Sans eux, la série est un nombre qui monte puis retombe, et il ne reste rien de ce qui
/// a été fait : quelqu'un qui a tenu trente jours puis oublié un mardi se retrouve à 1,
/// comme s'il n'avait jamais commencé. L'insigne, lui, est acquis — c'est la seule trace
/// permanente d'un effort qui, autrement, s'efface entièrement.
struct StreakBadge: Identifiable, Equatable {
    let days: Int
    let name: String
    let icon: String
    let colors: [Color]

    var id: Int { days }

    /// Gagné dès que la meilleure série jamais atteinte a franchi le palier.
    func isEarned(bestStreak: Int) -> Bool { bestStreak >= days }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let all: [StreakBadge] = [
        StreakBadge(days: 3, name: "Premier élan", icon: "sparkles",
                    colors: [Color(red: 1.00, green: 0.78, blue: 0.35), Color(red: 0.98, green: 0.58, blue: 0.20)]),
        StreakBadge(days: 7, name: "Une semaine", icon: "calendar",
                    colors: [Color(red: 1.00, green: 0.68, blue: 0.24), Color(red: 0.95, green: 0.36, blue: 0.16)]),
        StreakBadge(days: 14, name: "Deux semaines", icon: "bolt.fill",
                    colors: [Color(red: 0.98, green: 0.50, blue: 0.22), Color(red: 0.90, green: 0.24, blue: 0.24)]),
        StreakBadge(days: 30, name: "Un mois", icon: "moon.stars.fill",
                    colors: [Color(red: 0.62, green: 0.42, blue: 0.95), Color(red: 0.40, green: 0.28, blue: 0.85)]),
        StreakBadge(days: 60, name: "Deux mois", icon: "shield.fill",
                    colors: [Color(red: 0.30, green: 0.62, blue: 0.95), Color(red: 0.16, green: 0.38, blue: 0.82)]),
        StreakBadge(days: 100, name: "Cent jours", icon: "crown.fill",
                    colors: [Color(red: 1.00, green: 0.84, blue: 0.35), Color(red: 0.85, green: 0.60, blue: 0.10)]),
        StreakBadge(days: 180, name: "Six mois", icon: "trophy.fill",
                    colors: [Color(red: 0.36, green: 0.82, blue: 0.60), Color(red: 0.12, green: 0.58, blue: 0.42)]),
        StreakBadge(days: 365, name: "Une année", icon: "rosette",
                    colors: [Color(red: 0.98, green: 0.42, blue: 0.55), Color(red: 0.72, green: 0.16, blue: 0.42)])
    ]

    static func badge(for days: Int) -> StreakBadge? {
        all.first { $0.days == days }
    }
}
