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
            favorites.attachSession(userID: userID)
            let result = await userSyncService.syncOnSignIn(userID: userID)
            favorites.applyRemote(favoriteIDs: result.favoriteIDs)
            SharedDefaults.streakCount = result.streak
        } else {
            favorites.detachSession()
        }
        // Re-check StoreKit on every foreground: without this an expired or cancelled
        // subscription keeps unlocking premium content until the app is cold-launched.
        await store.refresh()
        await notificationManager.reschedule()
    }
}
