import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var syncState: SyncState
    @EnvironmentObject private var updateGate: AppUpdateGate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false
    @AppStorage("hasCompletedQuiz") private var hasCompletedQuiz = false
    @State private var selectedTab = 0
    @State private var focusedQuoteID: String?

    /// Intro → connexion → profil → quiz, puis l'app. Profil et quiz n'arrivent qu'une
    /// fois le compte créé.
    ///
    /// Ces étapes sont de simples branches plutôt qu'un fullScreenCover : la version
    /// précédente pilotait le cover par une liaison au setter vide, si bien qu'un
    /// `dismiss()` interne laissait la vue présentée sans jamais réévaluer son contenu —
    /// l'utilisateur restait sur l'écran de connexion alors que sa session était ouverte.
    var body: some View {
        Group {
            if updateGate.isUpdateRequired {
                // Avant tout le reste, connexion comprise : une version bloquée l'est
                // aussi pour quelqu'un qui n'a pas encore de compte.
                ForcedUpdateView(requiredVersion: updateGate.requiredVersion)
            } else if authManager.isRestoringSession {
                LaunchPlaceholderView()
                    // Le logo grandit en s'effaçant : la transition se lit comme un
                    // passage au premier plan, pas comme un écran qu'on remplace.
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
            } else if authManager.session == nil {
                // Une session ouverte prime sur le drapeau d'accueil : quelqu'un de
                // connecté ne doit jamais retomber sur l'intro ou la connexion, même si
                // l'étape d'accueil n'a pas eu l'occasion de se marquer terminée.
                if hasCompletedOnboarding {
                    LoginView()
                } else {
                    OnboardingView()
                }
            } else if !hasCompletedProfile, syncState.isAwaitingFirstSync {
                // Le profil existe peut-être déjà côté serveur, sans être encore arrivé
                // en local — changement de téléphone, réinstallation. Sans cette attente,
                // l'écran « Tu es ? » s'affichait le temps de la synchronisation, à
                // quelqu'un qui avait déjà tout renseigné.
                LaunchPlaceholderView()
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
            } else if !hasCompletedProfile {
                ProfileSetupView()
            } else if !hasCompletedQuiz {
                QuizView()
            } else {
                mainInterface
            }
        }
        // Amorti complet partout : ces bascules structurent la navigation, un rebond y
        // ferait passer un changement d'écran pour un effet.
        .animation(.spring(response: 0.45, dampingFraction: 1), value: authManager.isRestoringSession)
        .animation(.spring(response: 0.45, dampingFraction: 1), value: syncState.isAwaitingFirstSync)
        .animation(.spring(response: 0.45, dampingFraction: 1), value: hasCompletedProfile)
        .animation(.spring(response: 0.45, dampingFraction: 1), value: hasCompletedQuiz)
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
        .environmentObject(SyncState())
        .environmentObject(AppUpdateGate())
}
