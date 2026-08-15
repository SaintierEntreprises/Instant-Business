import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0

    private var needsAuthGate: Bool {
        !hasCompletedOnboarding || authManager.session == nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CardFeedView()
                .tabItem { Label("Découvrir", systemImage: "sparkles") }
                .tag(0)

            FavoritesView(onDiscoverTapped: { selectedTab = 0 })
                .tabItem { Label("Favoris", systemImage: "heart") }
                .tag(1)

            WidgetGalleryView()
                .tabItem { Label("Widget", systemImage: "square.grid.2x2") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
                .tag(3)
        }
        .fullScreenCover(isPresented: Binding(get: { needsAuthGate }, set: { _ in })) {
            if hasCompletedOnboarding {
                LoginView()
            } else {
                OnboardingView()
            }
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesStore())
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
}
