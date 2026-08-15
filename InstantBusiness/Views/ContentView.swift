import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CardFeedView()
                .tabItem { Label("Découvrir", systemImage: "sparkles") }

            FavoritesView()
                .tabItem { Label("Favoris", systemImage: "heart") }

            WidgetGalleryView()
                .tabItem { Label("Widget", systemImage: "square.grid.2x2") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesStore())
}
