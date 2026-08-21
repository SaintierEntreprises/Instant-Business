import Foundation
import Combine

/// Carries a quote opened from the widget or from a notification through to the feed.
///
/// Partagé plutôt qu'instancié par la vue : la réponse à une notification arrive par le
/// délégué `UNUserNotificationCenter`, qui vit dans l'`AppDelegate` et n'a aucun moyen
/// d'atteindre un objet d'environnement SwiftUI.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var pendingQuoteID: String?

    /// Origine de la mise au premier plan en cours, remise à `.direct` une fois mesurée :
    /// sans elle, impossible de distinguer une ouverture depuis une notification d'une
    /// ouverture depuis l'icône, et donc de savoir si les notifications servent.
    var launchSource: Analytics.Source = .direct

    func consumeLaunchSource() -> Analytics.Source {
        defer { launchSource = .direct }
        return launchSource
    }
}
