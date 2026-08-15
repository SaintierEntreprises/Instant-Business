import SwiftUI

@main
struct InstantBusinessApp: App {
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favorites)
        }
    }
}
