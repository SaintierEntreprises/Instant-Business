import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var syncState: SyncState
    @EnvironmentObject private var updateGate: AppUpdateGate
    @EnvironmentObject private var appearance: AppearanceStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false
    @AppStorage("hasCompletedQuiz") private var hasCompletedQuiz = false
    @State private var selectedTab = 0
    @State private var focusedQuoteID: String?
    @State private var streakCelebration: StreakCelebrationContext?

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
        // Posé à la racine : les feuilles présentées plus bas héritent de la valeur, il
        // n'y a donc rien à répéter écran par écran.
        .preferredColorScheme(appearance.appTheme.colorScheme)
    }

    /// Instantané figé au moment de la présentation.
    ///
    /// Présenter par `item:` plutôt que par `isPresented:` évite qu'une synchronisation
    /// arrivant pendant que la sheet est ouverte n'en change le contenu sous les yeux de
    /// la personne — la semaine se redessinerait au milieu de son animation d'entrée.
    private struct StreakCelebrationContext: Identifiable {
        let id = UUID()
        let streak: Int
        let bestStreak: Int
        let days: [StreakDay]
        let firstName: String?
        let milestone: StreakBadge?
        let freezeSavedDay: Date?
        let freezesRemaining: Int
    }

    /// Décide s'il faut célébrer la série, et le fait au plus une fois par jour.
    ///
    /// `forced` couvre l'arrivée par le rappel de série : cette notification n'existe que
    /// pour les jours où l'app n'a pas été ouverte, la règle du « une fois par jour » ne
    /// peut donc pas l'avoir déjà consommée — mais on la contourne explicitement plutôt
    /// que de compter dessus.
    @MainActor
    private func presentStreakCelebrationIfNeeded(forced: Bool = false) {
        guard streakCelebration == nil else { return }

        let streak = SharedDefaults.streakCount
        guard streak > 0 else { return }

        let openDays = SharedDefaults.openDays
        // Jamais le tout premier jour, sauf demande explicite : quelqu'un qui vient de
        // terminer les sept écrans d'inscription n'a pas de progression à consulter, et
        // une sheet de plus se lirait comme la suite de l'inscription.
        guard forced || openDays.count >= 2 else { return }

        let reachesMilestone = streak > SharedDefaults.celebratedMilestone
            && StreakBadge.badge(for: streak) != nil

        if !forced, !reachesMilestone,
           let last = SharedDefaults.lastStreakSheetDate,
           Calendar.current.isDateInToday(last) {
            return
        }

        // Palier franchi aujourd'hui, et pas encore fêté dans cette série. La comparaison
        // porte sur la série en cours, remise à zéro par `StreakManager` à chaque
        // rupture : un palier se refête dans une nouvelle série, il ne se fête pas deux
        // fois dans la même.
        let milestone: StreakBadge? = {
            guard streak > SharedDefaults.celebratedMilestone else { return nil }
            return StreakBadge.badge(for: streak)
        }()

        // Un joker ne couvre jamais que la veille : c'est donc exactement aujourd'hui, et
        // seulement aujourd'hui, qu'il y a lieu de l'annoncer.
        let freezeSavedDay = SharedDefaults.lastFreezeDate.flatMap {
            Calendar.current.isDateInYesterday($0) ? $0 : nil
        }

        let context = StreakCelebrationContext(
            streak: streak,
            bestStreak: max(SharedDefaults.bestStreak, streak),
            days: StreakWeek.days(streak: streak, openDays: openDays, frozenDays: SharedDefaults.frozenDays),
            firstName: SharedDefaults.firstName,
            milestone: milestone,
            freezeSavedDay: freezeSavedDay,
            freezesRemaining: SharedDefaults.freezesRemaining
        )

        Task { @MainActor in
            // Le temps que l'app finisse d'apparaître : présentée immédiatement, la sheet
            // remonte par-dessus une interface encore en train de se poser et les deux
            // animations se gênent.
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard streakCelebration == nil else { return }
            SharedDefaults.lastStreakSheetDate = Date()
            streakCelebration = context
            if let milestone = context.milestone {
                SharedDefaults.celebratedMilestone = milestone.days
                Analytics.track(.streakMilestoneReached, ["days": .int(milestone.days)])
            }
            if context.freezeSavedDay != nil {
                Analytics.track(.streakFreezeUsed, [
                    "streak": .int(context.streak),
                    "remaining": .int(context.freezesRemaining)
                ])
            }
            Analytics.track(.streakSheetShown, [
                "streak": .int(context.streak),
                "forced": .bool(forced),
                "milestone": .int(context.milestone?.days ?? 0)
            ])
        }
    }

    private func consumePendingQuote(_ quoteID: String?) {
        guard let quoteID else { return }
        selectedTab = 0
        focusedQuoteID = quoteID
        router.pendingQuoteID = nil
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
            consumePendingQuote(quoteID)
        }
        // App fermée au moment de l'appui : l'URL du widget, ou la réponse à la
        // notification, arrive pendant que l'écran de lancement est encore affiché. Le
        // fil n'existait pas encore, `onChange` ne voyait donc jamais rien passer et la
        // citation était perdue — le cas le plus courant, justement.
        .onAppear {
            consumePendingQuote(router.pendingQuoteID)
            // Le compteur ci-dessous peut déjà avoir été incrémenté avant que ce fil
            // n'existe — c'est même le cas le plus courant au lancement à froid, la
            // synchronisation démarrant pendant l'écran de lancement.
            presentStreakCelebrationIfNeeded(forced: router.pendingStreakCelebration)
            router.pendingStreakCelebration = false
        }
        .onChange(of: router.streakRefreshTick) { _, _ in
            presentStreakCelebrationIfNeeded(forced: router.pendingStreakCelebration)
            router.pendingStreakCelebration = false
        }
        .onChange(of: router.pendingStreakCelebration) { _, pending in
            guard pending else { return }
            router.pendingStreakCelebration = false
            presentStreakCelebrationIfNeeded(forced: true)
        }
        .sheet(item: $streakCelebration) { context in
            StreakCelebrationSheet(
                streak: context.streak,
                bestStreak: context.bestStreak,
                days: context.days,
                firstName: context.firstName,
                milestone: context.milestone,
                freezeSavedDay: context.freezeSavedDay,
                freezesRemaining: context.freezesRemaining
            )
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
