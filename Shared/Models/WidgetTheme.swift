import SwiftUI
import AppIntents

enum WidgetTheme: String, CaseIterable, AppEnum {
    case bold
    case minimal
    case gradient
    case dark

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Thème"

    static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .bold: "Bold",
        .minimal: "Minimal",
        .gradient: "Dégradé",
        .dark: "Sombre"
    ]

    var displayName: String {
        switch self {
        case .bold: return "Bold"
        case .minimal: return "Minimal"
        case .gradient: return "Dégradé"
        case .dark: return "Sombre"
        }
    }

    /// Only the default theme is free; the others require Premium.
    var isFree: Bool { self == .gradient }

    var previewGradient: [Color] {
        switch self {
        case .bold: return [.orange, .orange]
        case .minimal: return [Color(.systemBackground), Color(.systemBackground)]
        case .gradient: return [.orange, .black.opacity(0.85)]
        case .dark: return [.black, .black]
        }
    }
}
