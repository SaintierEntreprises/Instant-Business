import SwiftUI

@main
struct InstantBusinessApp: App {
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var store = StoreManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favorites)
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            StreakManager.recordOpenToday()
            Task { await notificationManager.reschedule() }
        }
    }
}
