import SwiftUI

/// Background style applied to quote cards (feed, daily card, shared image).
/// Distinct from `WidgetTheme`, which only styles the home-screen widget.
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    case couleur
    case creme
    case blanc
    case sombre
    case nuit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .couleur: return "Couleur"
        case .creme: return "Crème"
        case .blanc: return "Blanc"
        case .sombre: return "Sombre"
        case .nuit: return "Bleu nuit"
        }
    }

    var isFree: Bool {
        self == .couleur || self == .creme
    }

    /// True when the card sits on a light background and needs dark text.
    var isLight: Bool {
        self == .creme || self == .blanc
    }

    /// The card background. `category` only matters for `.couleur`, which keeps the
    /// per-category tint the app used before themes existed.
    func background(for category: QuoteCategory) -> LinearGradient {
        switch self {
        case .couleur:
            return LinearGradient(
                colors: [category.tint.opacity(0.95), category.tint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .creme:
            return LinearGradient(
                colors: [Color(red: 0.96, green: 0.94, blue: 0.90), Color(red: 0.92, green: 0.89, blue: 0.83)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blanc:
            return LinearGradient(
                colors: [Color.white, Color(white: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sombre:
            return LinearGradient(
                colors: [Color(white: 0.16), Color(white: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nuit:
            return LinearGradient(
                colors: [Color(red: 0.09, green: 0.13, blue: 0.24), Color(red: 0.05, green: 0.07, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var textColor: Color {
        isLight ? Color(white: 0.10) : .white
    }

    var secondaryTextColor: Color {
        isLight ? Color(white: 0.35) : .white.opacity(0.8)
    }

    /// Colour of the oversized decorative quote mark behind the text.
    var watermarkColor: Color {
        isLight ? .black.opacity(0.05) : .white.opacity(0.09)
    }

    func pillBackground(for category: QuoteCategory) -> Color {
        isLight ? category.tint.opacity(0.16) : .white.opacity(0.18)
    }

    func pillForeground(for category: QuoteCategory) -> Color {
        isLight ? category.tint : .white
    }

    var borderColor: Color {
        isLight ? .black.opacity(0.06) : .white.opacity(0.16)
    }

    func shadowColor(for category: QuoteCategory) -> Color {
        switch self {
        case .couleur: return category.tint.opacity(0.35)
        case .creme, .blanc: return .black.opacity(0.12)
        case .sombre, .nuit: return .black.opacity(0.3)
        }
    }
}
