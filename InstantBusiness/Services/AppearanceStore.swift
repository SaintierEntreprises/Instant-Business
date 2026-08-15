import Foundation
import Combine

@MainActor
final class AppearanceStore: ObservableObject {
    @Published var cardTheme: CardTheme {
        didSet { SharedDefaults.cardTheme = cardTheme }
    }

    init() {
        cardTheme = SharedDefaults.cardTheme
    }
}
