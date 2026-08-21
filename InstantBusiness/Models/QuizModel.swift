import Foundation

/// Quiz d'accueil en six questions. Chaque réponse pondère une ou plusieurs catégories ;
/// les totaux déterminent le profil affiché à la fin et les catégories présélectionnées
/// dans le fil.
///
/// Deux réponses portent en plus une information qui n'est pas un score : où en est la
/// personne (`QuizStage`, première question) et ce qu'elle vise (`QuizIntent`, dernière).
/// Sans elles, le quiz supposait que tout le monde était entrepreneur en activité —
/// quelqu'un venu uniquement pour les citations n'avait aucune réponse honnête à donner,
/// et quelqu'un de déjà installé n'était « freiné » par rien de ce qui était proposé.
struct QuizQuestion: Identifiable {
    let id: Int
    let prompt: String
    let options: [QuizOption]
}

struct QuizOption: Identifiable {
    let id = UUID()
    let label: String
    let symbol: String
    /// Points ajoutés par catégorie quand cette option est choisie.
    let weights: [QuoteCategory: Int]
    /// Renseigné uniquement par les options de la première question.
    var stage: QuizStage?
    /// Renseigné uniquement par les options de la dernière question.
    var intent: QuizIntent?
}

/// Où en est la personne. Ce n'est pas un score : deux personnes peuvent partager la même
/// catégorie dominante sans avoir le moindre besoin commun, selon qu'elles rêvent d'un
/// projet ou qu'elles dirigent déjà une équipe.
enum QuizStage {
    case inspiration    // aucune ambition entrepreneuriale affichée
    case reflexion      // y pense, sans projet précis
    case demarrage
    case projet
    case direction      // dirige déjà

    enum Bucket { case early, active, leading }

    /// Regroupement utilisé pour nuancer la description d'un profil.
    var bucket: Bucket {
        switch self {
        case .inspiration, .reflexion: return .early
        case .demarrage, .projet: return .active
        case .direction: return .leading
        }
    }
}

/// Ce que la personne vise à court terme.
enum QuizIntent {
    case nourrir        // rien à lancer, juste se nourrir l'esprit
    case lancer
    case croitre
    case structurer
    case consolider     // a déjà construit, cherche à tenir la distance

    /// Un objectif d'entreprise en cours, qui prime sur un stade déclaré plus tôt.
    var isBusinessDriven: Bool {
        switch self {
        case .lancer, .croitre, .structurer: return true
        case .nourrir, .consolider: return false
        }
    }
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
                QuizOption(
                    label: "Je viens surtout pour l'inspiration",
                    symbol: "sparkles",
                    weights: [.mindset: 3],
                    stage: .inspiration
                ),
                QuizOption(
                    label: "J'y pense, sans projet précis",
                    symbol: "lightbulb.fill",
                    weights: [.mindset: 2, .finance: 1],
                    stage: .reflexion
                ),
                QuizOption(
                    label: "Je démarre tout juste",
                    symbol: "sunrise.fill",
                    weights: [.mindset: 2, .sales: 2],
                    stage: .demarrage
                ),
                QuizOption(
                    label: "J'ai un projet en cours",
                    symbol: "hammer.fill",
                    weights: [.sales: 3, .mindset: 1],
                    stage: .projet
                ),
                QuizOption(
                    label: "Je dirige déjà une équipe",
                    symbol: "person.3.fill",
                    weights: [.leadership: 3, .finance: 1],
                    stage: .direction
                )
            ]
        ),
        QuizQuestion(
            id: 1,
            prompt: "Qu'est-ce qui te freine le plus ?",
            options: [
                QuizOption(label: "Le manque de discipline", symbol: "flame.fill", weights: [.mindset: 3]),
                QuizOption(label: "La peur de l'échec", symbol: "cloud.fill", weights: [.mindset: 3]),
                QuizOption(label: "Trouver des clients", symbol: "megaphone.fill", weights: [.sales: 3]),
                QuizOption(label: "Gérer l'argent", symbol: "eurosign.circle.fill", weights: [.finance: 3]),
                QuizOption(label: "Rien de bloquant en ce moment", symbol: "checkmark.seal.fill", weights: [.mindset: 2, .leadership: 1])
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
                QuizOption(
                    label: "Lancer mon projet",
                    symbol: "paperplane.fill",
                    weights: [.mindset: 2, .sales: 2],
                    intent: .lancer
                ),
                QuizOption(
                    label: "Augmenter mon chiffre",
                    symbol: "arrow.up.right.circle.fill",
                    weights: [.sales: 3, .finance: 1],
                    intent: .croitre
                ),
                QuizOption(
                    label: "Structurer mon équipe",
                    symbol: "person.2.fill",
                    weights: [.leadership: 4],
                    intent: .structurer
                ),
                QuizOption(
                    label: "Sécuriser ce que j'ai construit",
                    symbol: "shield.fill",
                    weights: [.finance: 4],
                    intent: .consolider
                ),
                QuizOption(
                    label: "Juste nourrir ma tête au quotidien",
                    symbol: "book.fill",
                    weights: [.mindset: 3],
                    intent: .nourrir
                )
            ]
        )
    ]

    // MARK: - Lecture des réponses

    /// Une seule option de tout le quiz porte un stade, d'où le `first` : l'ordre non
    /// déterministe de `answers.values` est ici sans effet.
    static func stage(from answers: [Int: QuizOption]) -> QuizStage? {
        answers.values.compactMap(\.stage).first
    }

    static func intent(from answers: [Int: QuizOption]) -> QuizIntent? {
        answers.values.compactMap(\.intent).first
    }

    /// Score normalisé 0...1 par catégorie, utilisé pour les barres du profil.
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

    // MARK: - Profil

    /// Le profil s'accorde au genre renseigné après la connexion (« La Déterminée » plutôt
    /// que « Le Déterminé ») et se nuance selon le stade : on ne dit pas la même chose à
    /// quelqu'un qui hésite encore qu'à quelqu'un qui dirige trente personnes.
    static func profile(
        for scores: [QuoteCategory: Double],
        gender: Gender? = SharedDefaults.gender,
        stage: QuizStage? = nil,
        intent: QuizIntent? = nil
    ) -> QuizProfile {
        let isFeminine = gender == .femme
        let e = isFeminine ? "e" : ""
        let article = isFeminine ? "La" : "Le"

        // Deux profils hors de l'échelle entrepreneuriale, sinon quelqu'un venu pour les
        // citations repartait étiqueté « Le Closer ».
        if intent == .nourrir || (stage == .inspiration && !(intent?.isBusinessDriven ?? false)) {
            return QuizProfile(
                name: "\(article) Curieu\(isFeminine ? "se" : "x")",
                tagline: "Tu n'as rien à prouver à personne. Tu viens chercher ce qui te tire vers le haut, et c'est déjà beaucoup.",
                symbol: "sparkles"
            )
        }

        if stage == .direction, intent == .consolider {
            return QuizProfile(
                name: "L'Accompli\(e)",
                tagline: "Tu as déjà construit. Le sujet n'est plus de courir, il est de tenir la distance.",
                symbol: "mountain.2.fill"
            )
        }

        let bucket = stage?.bucket ?? .active

        switch topCategory(scores) {
        case .mindset:
            return QuizProfile(
                name: "\(article) Déterminé\(e)",
                tagline: {
                    switch bucket {
                    case .early: return "Ton moteur, c'est le mental. C'est exactement ce qu'il faut pour passer de l'idée à l'action."
                    case .active: return "Ton moteur, c'est le mental. Tu avances quand les autres lâchent."
                    case .leading: return "Ton moteur, c'est le mental — et c'est ce que ton équipe vient chercher chez toi."
                    }
                }(),
                symbol: "flame.fill"
            )
        case .sales:
            return QuizProfile(
                name: "\(article) Closer",
                tagline: {
                    switch bucket {
                    case .early: return "Tu as l'instinct de convaincre. Il ne te manque qu'un terrain de jeu."
                    case .active: return "Tu es fait\(e) pour convaincre et pour vendre ce en quoi tu crois."
                    case .leading: return "Tu sais vendre. Ton enjeu maintenant, c'est de transmettre ce réflexe."
                    }
                }(),
                symbol: "megaphone.fill"
            )
        case .leadership:
            return QuizProfile(
                name: "\(article) Bâtisseu\(isFeminine ? "se" : "r")",
                tagline: {
                    switch bucket {
                    case .early: return "Tu penses déjà équipe et long terme, avant même d'en avoir une."
                    case .active: return "Tu penses équipe, vision et long terme."
                    case .leading: return "Tu penses équipe, vision et long terme — et tu le fais déjà au quotidien."
                    }
                }(),
                symbol: "person.3.fill"
            )
        case .finance:
            return QuizProfile(
                name: "\(article) Stratège",
                tagline: {
                    switch bucket {
                    case .early: return "Tu raisonnes chiffres avant même de te lancer. C'est plus rare qu'on ne croit."
                    case .active: return "Tu raisonnes chiffres, marges et indépendance financière."
                    case .leading: return "Tu raisonnes chiffres, marges et indépendance. C'est ce qui garde la maison debout."
                    }
                }(),
                symbol: "chart.line.uptrend.xyaxis"
            )
        }
    }

    /// Catégories à présélectionner : tout ce qui atteint 60 % du meilleur score.
    static func preferredCategories(for scores: [QuoteCategory: Double]) -> [QuoteCategory] {
        QuoteCategory.allCases
            .filter { (scores[$0] ?? 0) >= 0.6 }
            .sorted { lhs, rhs in
                let left = scores[lhs] ?? 0
                let right = scores[rhs] ?? 0
                if left != right { return left > right }
                return rank(lhs) < rank(rhs)
            }
    }

    /// Départage explicite des ex æquo. Auparavant le maximum était pris directement sur
    /// le dictionnaire des scores : à égalité — ce qui arrive dès qu'on répond « Tout le
    /// temps » — l'ordre de parcours d'un dictionnaire Swift varie d'un lancement à
    /// l'autre, et le profil affiché changeait donc sans raison visible.
    private static func topCategory(_ scores: [QuoteCategory: Double]) -> QuoteCategory {
        QuoteCategory.allCases.max { lhs, rhs in
            let left = scores[lhs] ?? 0
            let right = scores[rhs] ?? 0
            if left != right { return left < right }
            return rank(lhs) > rank(rhs)
        } ?? .mindset
    }

    private static func rank(_ category: QuoteCategory) -> Int {
        QuoteCategory.allCases.firstIndex(of: category) ?? 0
    }
}
