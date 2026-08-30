import SwiftUI

/// Apparence de l'interface de l'app, indépendante de `CardTheme`.
///
/// `CardTheme` n'habille que le fond des cartes de citation ; celui-ci décide du clair ou
/// du sombre pour tout le reste — fond des écrans, réglages, feuilles. Les deux sont
/// volontairement séparés : on peut vouloir des cartes crème sur une app en sombre.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    static var `default`: AppTheme { .system }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Automatique"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    var summary: String {
        switch self {
        case .system: return "suit iOS"
        case .light: return "toujours clair"
        case .dark: return "toujours sombre"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    /// `nil` laisse iOS décider, y compris au passage automatique du soir. Forcer une
    /// valeur ici priverait de ce basculement, d'où le choix « Automatique » par défaut.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
