import SwiftUI
import GoogleSignIn

@main
struct InstantBusinessApp: App {
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var store = StoreManager()
    @StateObject private var authManager = AuthManager()
    @StateObject private var router = AppRouter()
    @StateObject private var appearance = AppearanceStore()
    @Environment(\.scenePhase) private var scenePhase

    private let userSyncService = UserSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favorites)
                .environmentObject(store)
                .environmentObject(authManager)
                .environmentObject(router)
                .environmentObject(appearance)
                .onOpenURL { url in
                    // Single entry point: Google's callback and the widget deep link
                    // arrive the same way, so they are routed here rather than in
                    // competing handlers.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    if let quoteID = DeepLink.quoteID(from: url) {
                        router.pendingQuoteID = quoteID
                    }
                }
                .onChange(of: authManager.session != nil) { _, isSignedIn in
                    if isSignedIn {
                        Task { await syncOnForeground() }
                    } else {
                        favorites.detachSession()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await syncOnForeground() }
        }
    }

    private func syncOnForeground() async {
        if let userID = authManager.session?.user.id.uuidString {
            discardDataFromAnotherAccount(newUserID: userID)
            favorites.attachSession(userID: userID)
            let result = await userSyncService.syncOnSignIn(userID: userID)

            // Chaque valeur n'est appliquée que si le serveur a réellement répondu : hors
            // ligne, mieux vaut afficher l'état local un peu daté qu'une liste de favoris
            // vide et une série remise à zéro.
            if let remoteFavorites = result.favoriteIDs {
                favorites.applyRemote(favoriteIDs: remoteFavorites)
            }
            if let remoteStreak = result.streak {
                SharedDefaults.streakCount = remoteStreak
            } else {
                StreakManager.recordOpenToday()
            }

            // Le profil vit côté serveur : sur un nouvel appareil, on le restaure plutôt
            // que de redemander prénom et genre à quelqu'un qui les a déjà renseignés.
            if let firstName = result.profile.firstName, !firstName.isEmpty {
                SharedDefaults.firstName = firstName
                SharedDefaults.lastName = result.profile.lastName
                SharedDefaults.gender = result.profile.gender
                UserDefaults.standard.set(true, forKey: "hasCompletedProfile")
            }
        } else {
            favorites.detachSession()
        }
        // Re-check StoreKit on every foreground: without this an expired or cancelled
        // subscription keeps unlocking premium content until the app is cold-launched.
        await store.refresh()
        await notificationManager.reschedule()
    }

    /// `signOut()` ne nettoyait rien en local : quelqu'un qui se connectait ensuite sur le
    /// même téléphone héritait des favoris, de la série et du prénom du compte précédent,
    /// et n'était même pas invité à saisir les siens puisque le profil était marqué
    /// terminé. On compare donc l'identifiant du compte à celui dont proviennent les
    /// données présentes, et on efface uniquement s'il a changé — se reconnecter avec le
    /// même compte ne fait donc rien reperdre.
    private func discardDataFromAnotherAccount(newUserID: String) {
        guard SharedDefaults.accountUserID != newUserID else { return }
        if SharedDefaults.accountUserID != nil {
            SharedDefaults.resetAccountData()
            UserDefaults.standard.removeObject(forKey: "hasCompletedProfile")
            UserDefaults.standard.removeObject(forKey: "hasCompletedQuiz")
            favorites.applyRemote(favoriteIDs: [])
        }
        SharedDefaults.accountUserID = newUserID
    }
}
