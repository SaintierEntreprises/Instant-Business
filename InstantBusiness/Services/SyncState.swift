import Foundation
import Combine

/// Suit la première synchronisation serveur d'un compte donné.
///
/// Sans ce suivi, `ContentView` tranchait immédiatement sur le drapeau local
/// `hasCompletedProfile` : quelqu'un qui change de téléphone ou réinstalle l'app a bien
/// son profil côté serveur, mais pas encore en local, et voyait donc l'écran « Tu es ? »
/// apparaître le temps que la synchronisation réponde — assez longtemps pour commencer
/// à répondre à une question déjà renseignée.
@MainActor
final class SyncState: ObservableObject {
    /// Vrai tant que le serveur n'a pas répondu au moins une fois pour ce compte.
    @Published private(set) var isAwaitingFirstSync = false

    /// Comptes dont la première synchronisation a déjà eu lieu pendant cette session.
    /// Le retour au premier plan resynchronise, mais ne doit plus rien faire attendre.
    private var settledUserIDs: Set<String> = []
    private var timeout: Task<Void, Never>?

    func beginFirstSync(userID: String) {
        guard !settledUserIDs.contains(userID) else { return }
        isAwaitingFirstSync = true

        // Filet de sécurité, comme pour la restauration de session : une requête qui ne
        // rend jamais la main ne doit pas laisser l'app bloquée sur son logo.
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.isAwaitingFirstSync = false
        }
    }

    func endFirstSync(userID: String) {
        settledUserIDs.insert(userID)
        timeout?.cancel()
        timeout = nil
        isAwaitingFirstSync = false
    }

    /// À la déconnexion : le compte suivant doit de nouveau attendre sa synchronisation.
    func reset() {
        settledUserIDs.removeAll()
        timeout?.cancel()
        timeout = nil
        isAwaitingFirstSync = false
    }
}
