import Foundation
import Combine

/// Carries a quote opened from the widget through to the feed.
@MainActor
final class AppRouter: ObservableObject {
    @Published var pendingQuoteID: String?
}
