import SwiftUI

enum QuoteCategory: String, Codable, CaseIterable, Identifiable {
    case mindset
    case sales
    case leadership
    case finance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mindset: return "Mindset & Motivation"
        case .sales: return "Vente & Marketing"
        case .leadership: return "Leadership"
        case .finance: return "Argent & Finance"
        }
    }

    var symbolName: String {
        switch self {
        case .mindset: return "flame.fill"
        case .sales: return "megaphone.fill"
        case .leadership: return "person.3.fill"
        case .finance: return "chart.line.uptrend.xyaxis"
        }
    }

    var tint: Color {
        switch self {
        case .mindset: return .orange
        case .sales: return .pink
        case .leadership: return .indigo
        case .finance: return .green
        }
    }
}
