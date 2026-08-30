import Foundation
import Combine

@MainActor
final class AppearanceStore: ObservableObject {
    @Published var cardTheme: CardTheme {
        didSet { SharedDefaults.cardTheme = cardTheme }
    }

    /// Volontairement conservée à la déconnexion, contrairement au thème des cartes :
    /// c'est un réglage de confort de lecture propre à l'appareil, pas une préférence de
    /// compte. Se déconnecter ne doit pas rallumer un écran blanc en pleine nuit.
    @Published var appTheme: AppTheme {
        didSet { SharedDefaults.appTheme = appTheme }
    }

    init() {
        cardTheme = SharedDefaults.cardTheme
        appTheme = SharedDefaults.appTheme
    }
}
