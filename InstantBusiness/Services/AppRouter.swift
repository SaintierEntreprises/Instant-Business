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

    /// Incrémenté à la fin de chaque synchronisation d'ouverture, une fois la série et
    /// l'historique des jours à jour.
    ///
    /// La célébration ne peut pas se décider à l'apparition de la vue : la série arrive du
    /// serveur quelques centaines de millisecondes plus tard, et on afficherait une
    /// semaine encore vide. Ce compteur est le seul signal qui dit « les données sont
    /// posées, tu peux décider ».
    @Published var streakRefreshTick = 0

    /// Posé quand l'app est ouverte depuis le rappel de série, consommé par `ContentView`
    /// qui présente alors la célébration sans attendre la règle du « une fois par jour ».
    @Published var pendingStreakCelebration = false

    /// Origine de la mise au premier plan en cours, remise à `.direct` une fois mesurée :
    /// sans elle, impossible de distinguer une ouverture depuis une notification d'une
    /// ouverture depuis l'icône, et donc de savoir si les notifications servent.
    var launchSource: Analytics.Source = .direct

    func consumeLaunchSource() -> Analytics.Source {
        defer { launchSource = .direct }
        return launchSource
    }
}
