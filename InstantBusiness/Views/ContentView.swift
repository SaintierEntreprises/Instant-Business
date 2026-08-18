import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var router: AppRouter
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedQuiz") private var hasCompletedQuiz = false
    @State private var selectedTab = 0
    @State private var focusedQuoteID: String?

    /// Intro → connexion → quiz, puis l'app. Le quiz n'arrive qu'une fois le compte créé.
    ///
    /// Ces étapes sont de simples branches plutôt qu'un fullScreenCover : la version
    /// précédente pilotait le cover par une liaison au setter vide, si bien qu'un
    /// `dismiss()` interne laissait la vue présentée sans jamais réévaluer son contenu —
    /// l'utilisateur restait sur l'écran de connexion alors que sa session était ouverte.
    var body: some View {
        Group {
            if authManager.isRestoringSession {
                LaunchPlaceholderView()
            } else if !hasCompletedOnboarding {
                OnboardingView()
            } else if authManager.session == nil {
                LoginView()
            } else if !hasCompletedQuiz {
                QuizView()
            } else {
                mainInterface
            }
        }
        .animation(.easeOut(duration: 0.2), value: authManager.isRestoringSession)
        .fontDesign(.rounded)
    }

    private var mainInterface: some View {
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
        .onChange(of: router.pendingQuoteID) { _, quoteID in
            guard let quoteID else { return }
            selectedTab = 0
            focusedQuoteID = quoteID
            router.pendingQuoteID = nil
        }
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
