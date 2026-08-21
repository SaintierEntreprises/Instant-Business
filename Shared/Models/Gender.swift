import Foundation

/// Sert uniquement à l'accord grammatical (profils du quiz, salutations).
enum Gender: String, CaseIterable, Identifiable, Codable {
    case homme
    case femme

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homme: return "Homme"
        case .femme: return "Femme"
        }
    }

    var symbolName: String {
        switch self {
        case .homme: return "person.fill"
        case .femme: return "person.fill"
        }
    }

    /// « e » à ajouter aux participes et adjectifs accordés.
    var feminineSuffix: String {
        self == .femme ? "e" : ""
    }
}
