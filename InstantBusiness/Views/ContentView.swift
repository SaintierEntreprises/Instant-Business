import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var router: AppRouter
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedQuiz") private var hasCompletedQuiz = false
    @State private var selectedTab = 0
    @State private var focusedQuoteID: String?

    /// Intro → connexion → quiz, puis l'app. Le quiz n'arrive qu'une fois le compte créé.
    private var needsGate: Bool {
        !hasCompletedOnboarding || authManager.session == nil || !hasCompletedQuiz
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CardFeedView(focusedQuoteID: $focusedQuoteID)
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
        .fullScreenCover(isPresented: Binding(get: { needsGate }, set: { _ in })) {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if authManager.session == nil {
                LoginView()
            } else {
                QuizView()
            }
        }
        .onChange(of: router.pendingQuoteID) { _, quoteID in
            guard let quoteID else { return }
            selectedTab = 0
            focusedQuoteID = quoteID
            router.pendingQuoteID = nil
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesStore())
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
        .environmentObject(AppRouter())
        .environmentObject(AppearanceStore())
}
