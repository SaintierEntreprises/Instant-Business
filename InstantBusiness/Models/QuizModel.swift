import Foundation

/// Six-question onboarding quiz. Each answer adds weight to one or more categories;
/// the totals drive both the profile shown at the end and the categories pre-selected
/// in the feed.
struct QuizQuestion: Identifiable {
    let id: Int
    let prompt: String
    let options: [QuizOption]
}

struct QuizOption: Identifiable {
    let id = UUID()
    let label: String
    let symbol: String
    /// Points added per category when this option is picked.
    let weights: [QuoteCategory: Int]
}

struct QuizProfile {
    let name: String
    let tagline: String
    let symbol: String
}

enum Quiz {
    static let questions: [QuizQuestion] = [
        QuizQuestion(
            id: 0,
            prompt: "Où en es-tu aujourd'hui ?",
            options: [
                QuizOption(label: "Je démarre tout juste", symbol: "sparkles", weights: [.mindset: 3, .sales: 1]),
                QuizOption(label: "J'ai un projet en cours", symbol: "hammer.fill", weights: [.sales: 3, .mindset: 1]),
                QuizOption(label: "Je dirige déjà une équipe", symbol: "person.3.fill", weights: [.leadership: 3]),
                QuizOption(label: "Je me forme avant de me lancer", symbol: "book.fill", weights: [.mindset: 2, .finance: 2])
            ]
        ),
        QuizQuestion(
            id: 1,
            prompt: "Qu'est-ce qui te freine le plus ?",
            options: [
                QuizOption(label: "Le manque de discipline", symbol: "flame.fill", weights: [.mindset: 3]),
                QuizOption(label: "La peur de l'échec", symbol: "cloud.fill", weights: [.mindset: 3]),
                QuizOption(label: "Trouver des clients", symbol: "megaphone.fill", weights: [.sales: 3]),
                QuizOption(label: "Gérer l'argent", symbol: "eurosign.circle.fill", weights: [.finance: 3])
            ]
        ),
        QuizQuestion(
            id: 2,
            prompt: "Que veux-tu développer en priorité ?",
            options: [
                QuizOption(label: "Mon mental", symbol: "brain.head.profile", weights: [.mindset: 4]),
                QuizOption(label: "Mes ventes", symbol: "chart.line.uptrend.xyaxis", weights: [.sales: 4]),
                QuizOption(label: "Mon leadership", symbol: "flag.fill", weights: [.leadership: 4]),
                QuizOption(label: "Mes finances", symbol: "banknote.fill", weights: [.finance: 4])
            ]
        ),
        QuizQuestion(
            id: 3,
            prompt: "Quel ton te motive le plus ?",
            options: [
                QuizOption(label: "Cash et direct", symbol: "bolt.fill", weights: [.sales: 2, .mindset: 2]),
                QuizOption(label: "Inspirant", symbol: "sun.max.fill", weights: [.mindset: 3]),
                QuizOption(label: "Stratégique", symbol: "target", weights: [.leadership: 2, .finance: 2]),
                QuizOption(label: "Philosophique", symbol: "quote.opening", weights: [.mindset: 2, .leadership: 1])
            ]
        ),
        QuizQuestion(
            id: 4,
            prompt: "Quand as-tu besoin d'un boost ?",
            options: [
                QuizOption(label: "Au réveil", symbol: "sunrise.fill", weights: [.mindset: 2]),
                QuizOption(label: "En pleine journée", symbol: "sun.max.fill", weights: [.sales: 2]),
                QuizOption(label: "Le soir", symbol: "moon.stars.fill", weights: [.leadership: 2]),
                QuizOption(label: "Tout le temps", symbol: "infinity", weights: [.mindset: 1, .sales: 1, .leadership: 1, .finance: 1])
            ]
        ),
        QuizQuestion(
            id: 5,
            prompt: "Ton objectif des 6 prochains mois ?",
            options: [
                QuizOption(label: "Lancer mon projet", symbol: "paperplane.fill", weights: [.mindset: 2, .sales: 2]),
                QuizOption(label: "Augmenter mon chiffre", symbol: "arrow.up.right.circle.fill", weights: [.sales: 3, .finance: 1]),
                QuizOption(label: "Structurer mon équipe", symbol: "person.2.fill", weights: [.leadership: 4]),
                QuizOption(label: "Sécuriser mes finances", symbol: "shield.fill", weights: [.finance: 4])
            ]
        )
    ]

    /// Normalised 0...1 score per category, used for the profile bars.
    static func scores(for answers: [Int: QuizOption]) -> [QuoteCategory: Double] {
        var raw: [QuoteCategory: Int] = [:]
        for option in answers.values {
            for (category, weight) in option.weights {
                raw[category, default: 0] += weight
            }
        }
        let maxValue = max(raw.values.max() ?? 1, 1)
        return QuoteCategory.allCases.reduce(into: [:]) { result, category in
            result[category] = Double(raw[category] ?? 0) / Double(maxValue)
        }
    }

    /// Le profil s'accorde au genre renseigné après la connexion : « La Déterminée »
    /// plutôt que « Le Déterminé ».
    static func profile(for scores: [QuoteCategory: Double], gender: Gender? = SharedDefaults.gender) -> QuizProfile {
        let top = scores.max { $0.value < $1.value }?.key ?? .mindset
        let isFeminine = gender == .femme
        let article = isFeminine ? "La" : "Le"

        switch top {
        case .mindset:
            return QuizProfile(
                name: "\(article) Déterminé\(isFeminine ? "e" : "")",
                tagline: "Ton moteur, c'est le mental. Tu avances quand les autres lâchent.",
                symbol: "flame.fill"
            )
        case .sales:
            return QuizProfile(
                name: "\(article) Closer",
                tagline: "Tu es fait\(isFeminine ? "e" : "") pour convaincre et pour vendre ce en quoi tu crois.",
                symbol: "megaphone.fill"
            )
        case .leadership:
            return QuizProfile(
                name: "\(article) Bâtisseu\(isFeminine ? "se" : "r")",
                tagline: "Tu penses équipe, vision et long terme.",
                symbol: "person.3.fill"
            )
        case .finance:
            return QuizProfile(
                name: "\(article) Stratège",
                tagline: "Tu raisonnes chiffres, marges et indépendance financière.",
                symbol: "chart.line.uptrend.xyaxis"
            )
        }
    }

    /// Categories worth pre-selecting: everything scoring at least 60% of the top score.
    static func preferredCategories(for scores: [QuoteCategory: Double]) -> [QuoteCategory] {
        scores.filter { $0.value >= 0.6 }
            .sorted { $0.value > $1.value }
            .map(\.key)
    }
}
