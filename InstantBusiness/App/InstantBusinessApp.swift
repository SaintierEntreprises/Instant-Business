import SwiftUI
import GoogleSignIn

@main
struct InstantBusinessApp: App {
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var store = StoreManager()
    @StateObject private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase

    private let userSyncService = UserSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favorites)
                .environmentObject(store)
                .environmentObject(authManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
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
        await notificationManager.reschedule()
    }
}
