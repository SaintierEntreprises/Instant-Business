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
}
