import Foundation

/// Quiz d'accueil en trois questions. Chaque réponse pondère une ou plusieurs catégories ;
/// les totaux déterminent le profil affiché à la fin et les catégories présélectionnées
/// dans le fil.
///
/// Trois et pas six : les questions écartées — ce qui te freine, quel ton te motive, quand
/// tu as besoin d'un boost — nuançaient le profil sans jamais changer ce que la personne
/// voit dans son fil. Dix écrans avant d'entrer dans une app de citations font renoncer
/// plus de monde qu'un profil finement ciselé n'en retient.
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
    /// Identifiant stable du profil, jamais affiché. Sert uniquement à segmenter les
    /// données d'usage : le nom visible a été retiré parce qu'aucune formulation ne
    /// paraissait à la fois juste et parlante, et qu'un titre qu'on trouve creux fait
    /// plus de mal que pas de titre du tout.
    let key: String
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
            prompt: "Que veux-tu développer en priorité ?",
            options: [
                QuizOption(label: "Mon mental", symbol: "brain.head.profile", weights: [.mindset: 4]),
                QuizOption(label: "Mes ventes", symbol: "chart.line.uptrend.xyaxis", weights: [.sales: 4]),
                QuizOption(label: "Mon leadership", symbol: "flag.fill", weights: [.leadership: 4]),
                QuizOption(label: "Mes finances", symbol: "banknote.fill", weights: [.finance: 4])
            ]
        ),
        QuizQuestion(
            id: 2,
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

    /// La description s'accorde au genre renseigné après la connexion et se nuance selon
    /// le stade : on ne dit pas la même chose à quelqu'un qui hésite encore qu'à quelqu'un
    /// qui dirige trente personnes.
    static func profile(
        for scores: [QuoteCategory: Double],
        gender: Gender? = SharedDefaults.gender,
        stage: QuizStage? = nil,
        intent: QuizIntent? = nil
    ) -> QuizProfile {
        // Seules les descriptions s'accordent désormais : les noms de profil, qui
        // portaient l'essentiel de l'accord, ont été retirés.
        let e = gender == .femme ? "e" : ""

        // Deux profils hors de l'échelle entrepreneuriale : sans eux, quelqu'un venu
        // uniquement pour les citations recevait une description d'entrepreneur.
        if intent == .nourrir || (stage == .inspiration && !(intent?.isBusinessDriven ?? false)) {
            return QuizProfile(
                key: "curieux",
                tagline: "Tu n'as rien à prouver. Tu viens chercher ce qui te tire vers le haut.",
                symbol: "sparkles"
            )
        }

        if stage == .direction, intent == .consolider {
            return QuizProfile(
                key: "accompli",
                tagline: "Tu as déjà construit. Le sujet maintenant, c'est de tenir la distance.",
                symbol: "mountain.2.fill"
            )
        }

        let bucket = stage?.bucket ?? .active

        switch topCategory(scores) {
        case .mindset:
            return QuizProfile(
                key: "mindset",
                tagline: {
                    switch bucket {
                    case .early: return "Ton moteur, c'est le mental. De quoi passer de l'idée à l'action."
                    case .active: return "Ton moteur, c'est le mental. Tu avances quand les autres lâchent."
                    case .leading: return "Ton moteur, c'est le mental. C'est ce que ton équipe vient chercher."
                    }
                }(),
                symbol: "flame.fill"
            )
        case .sales:
            return QuizProfile(
                key: "sales",
                tagline: {
                    switch bucket {
                    case .early: return "Tu as l'instinct de convaincre. Il te manque un terrain de jeu."
                    case .active: return "Tu es fait\(e) pour convaincre et vendre ce en quoi tu crois."
                    case .leading: return "Tu sais vendre. Ton enjeu, c'est de transmettre ce réflexe."
                    }
                }(),
                symbol: "megaphone.fill"
            )
        case .leadership:
            return QuizProfile(
                key: "leadership",
                tagline: {
                    switch bucket {
                    case .early: return "Tu penses équipe et long terme, avant même d'avoir une équipe."
                    case .active: return "Tu penses équipe, vision et long terme."
                    case .leading: return "Tu penses équipe et long terme, et tu le fais déjà au quotidien."
                    }
                }(),
                symbol: "person.3.fill"
            )
        case .finance:
            return QuizProfile(
                key: "finance",
                tagline: {
                    switch bucket {
                    case .early: return "Tu raisonnes chiffres avant de te lancer. C'est plus rare qu'on croit."
                    case .active: return "Tu raisonnes chiffres, marges et indépendance."
                    case .leading: return "Tu raisonnes chiffres et indépendance. C'est ce qui tient la maison."
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
