import Foundation

/// Nombre de citations reçues par jour, choisi à l'inscription et modifiable dans les
/// réglages.
///
/// Les horaires sont tous compris entre 8h et 21h. La version précédente programmait des
/// créneaux fixes toutes les quatre heures à partir de minuit — donc une notification à
/// minuit et une autre à 4h du matin. C'est très probablement ce qui a poussé plusieurs
/// personnes à tout couper : une app de motivation qui réveille la nuit ne se fait pas
/// désactiver pour son contenu, mais pour son horaire.
enum NotificationFrequency: String, CaseIterable, Identifiable, Codable {
    case light
    /// Deux par jour, une au réveil et une en soirée.
    ///
    /// Déclarée entre `light` et `balanced` et non à la fin : `allCases` dicte l'ordre
    /// d'affichage des sélecteurs, qui doivent rester classés du rythme le plus calme au
    /// plus soutenu.
    case duo
    case balanced
    case frequent

    var id: String { rawValue }

    /// Choix par défaut, appliqué aussi à qui n'a jamais rien réglé.
    ///
    /// Deux par jour plutôt que trois : c'est le rythme qui encadre la journée sans
    /// l'occuper — une citation au réveil, une le soir — et il colle au geste que l'app
    /// demande vraiment, qui est d'ouvrir l'app une fois par jour pour tenir sa série.
    /// Changer cette valeur ne touche que les personnes qui n'ont jamais réglé leur
    /// rythme : un choix explicite est stocké et prime toujours.
    static let `default`: NotificationFrequency = .duo

    var displayName: String {
        switch self {
        case .light: return "Légère"
        case .duo: return "Matin et soir"
        case .balanced: return "Équilibrée"
        case .frequent: return "Intense"
        }
    }

    var summary: String {
        switch self {
        case .light: return "1 citation par jour"
        case .duo: return "2 citations par jour"
        case .balanced: return "3 citations par jour"
        case .frequent: return "6 citations par jour"
        }
    }

    var detail: String {
        switch self {
        case .light: return "Le matin, et c'est tout."
        case .duo: return "Une au réveil, une en soirée."
        case .balanced: return "Matin, après-midi et soirée."
        case .frequent: return "Toute la journée, de 8h à 21h."
        }
    }

    var symbolName: String {
        switch self {
        case .light: return "sunrise.fill"
        case .duo: return "sun.horizon.fill"
        case .balanced: return "sun.max.fill"
        case .frequent: return "bolt.fill"
        }
    }

    /// Heures d'envoi, dans l'ordre. La première porte la citation du jour, les
    /// suivantes la rotation propre à chaque installation.
    var hours: [Int] {
        switch self {
        case .light: return [9]
        // Mêmes ancres que les autres rythmes : 9h et 20h y figurent déjà, les créneaux
        // restent donc alignés d'un réglage à l'autre.
        case .duo: return [9, 20]
        case .balanced: return [9, 14, 20]
        case .frequent: return [8, 10, 13, 16, 19, 21]
        }
    }

    var perDay: Int { hours.count }
}
