import Foundation

/// Remonte les réglages d'usage vers le serveur dès qu'ils changent.
///
/// Centralisé plutôt qu'appelé depuis chaque écran : ces réglages se modifient à sept
/// endroits — deux sélecteurs de réglages, l'écran de profil, la galerie de widgets,
/// l'activation des notifications — et un seul oubli suffirait à faire reperdre un choix
/// à la réinstallation, sans que rien ne le signale.
@MainActor
enum PreferenceSync {
    private static let service = UserSyncService()

    /// Sans compte connecté, il n'y a nulle part où écrire : les réglages restent locaux
    /// et partiront au prochain envoi, une fois la session ouverte.
    static func push() {
        guard let userID = AuthSession.currentUserID else { return }
        Task { await service.savePreferences(userID: userID) }
    }
}

/// Identifiant du compte en cours, lisible sans passer par l'environnement SwiftUI.
///
/// `AuthManager` est un objet d'environnement : les services et les vues profondes n'y ont
/// pas accès. L'identifiant est donc recopié ici à chaque changement de session, pour que
/// l'envoi des réglages ne dépende pas de l'endroit d'où il est déclenché.
@MainActor
enum AuthSession {
    static var currentUserID: String?
}
