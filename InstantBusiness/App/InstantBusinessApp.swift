import SwiftUI
import GoogleSignIn
import WidgetKit

@main
struct InstantBusinessApp: App {
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var store = StoreManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var router = AppRouter.shared
    @StateObject private var appearance = AppearanceStore()
    @StateObject private var syncState = SyncState()
    @StateObject private var updateGate = AppUpdateGate()
    @Environment(\.scenePhase) private var scenePhase

    /// `notificationManager.enable()` — la seule chose qui demande vraiment l'autorisation
    /// et arme les notifications — n'était appelée qu'à l'instant précis de la toute
    /// première connexion (dans OnboardingView). Quiconque avait un compte avant, ou dont
    /// le drapeau local `notificationsEnabled` a été perdu (réinstallation, TestFlight),
    /// n'avait plus aucun chemin pour jamais rien activer : `reschedule()` se contente de
    /// ne rien faire si ce drapeau est à faux, sa valeur par défaut. Ce drapeau garantit
    /// qu'on demande une bonne fois pour toutes, pour chaque installation, sans jamais
    /// re-solliciter quelqu'un qui a déjà refusé ou désactivé volontairement.
    @AppStorage("hasRequestedNotificationPermission") private var hasRequestedNotificationPermission = false

    private let userSyncService = UserSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favorites)
                .environmentObject(store)
                .environmentObject(authManager)
                .environmentObject(router)
                .environmentObject(appearance)
                .environmentObject(syncState)
                .environmentObject(updateGate)
                .onOpenURL { url in
                    // Single entry point: Google's callback and the widget deep link
                    // arrive the same way, so they are routed here rather than in
                    // competing handlers.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    if let quoteID = DeepLink.quoteID(from: url) {
                        Analytics.track(.widgetOpened, ["quote_id": .string(quoteID)])
                        router.launchSource = .widget
                        router.pendingQuoteID = quoteID

                        // La citation vient d'être lue dans l'app : on avance la rotation
                        // et on redemande une timeline, sinon on revient à l'écran
                        // d'accueil pour retrouver exactement celle qu'on quitte.
                        ContentStore.advanceRotation()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                .onChange(of: authManager.session != nil) { _, isSignedIn in
                    if isSignedIn {
                        Task { await syncOnForeground() }
                    } else {
                        favorites.detachSession()
                        syncState.reset()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                // Dernier moment sûr pour descendre sur disque ce qui a été lu : l'app
                // peut être tuée en arrière-plan sans autre préavis.
                SeenQuotes.flush()
                return
            }
            Task { await syncOnForeground() }
        }
    }

    private func syncOnForeground() async {
        // Écrit avant tout le reste : c'est ce qui dit au planificateur que la série du
        // jour est sécurisée, et donc qu'il ne faut pas rappeler quoi que ce soit ce soir.
        SharedDefaults.lastForegroundDate = Date()

        if let userID = authManager.session?.user.id.uuidString {
            // Marqué avant le moindre await : c'est ce drapeau qui retient l'affichage du
            // profil, il ne servirait à rien s'il arrivait après une requête réseau.
            syncState.beginFirstSync(userID: userID)
            discardDataFromAnotherAccount(newUserID: userID)
            favorites.attachSession(userID: userID)

            // La version minimale ne dépend pas du compte : les deux requêtes partent
            // ensemble plutôt que l'une après l'autre.
            async let versionCheck: Void = updateGate.refresh()
            let result = await userSyncService.syncOnSignIn(userID: userID)
            await versionCheck
            syncState.endFirstSync(userID: userID)

            // Chaque valeur n'est appliquée que si le serveur a réellement répondu : hors
            // ligne, mieux vaut afficher l'état local un peu daté qu'une liste de favoris
            // vide et une série remise à zéro.
            if let remoteFavorites = result.favoriteIDs {
                favorites.applyRemote(favoriteIDs: remoteFavorites)
            }
            // Avant `store.refresh()`, qui recalcule Premium à partir des deux sources.
            store.applyGrantedPremium(result.grantedPremium)

            if let remoteStreak = result.streak {
                SharedDefaults.streakCount = remoteStreak
            } else {
                StreakManager.recordOpenToday()
            }

            // Après la résolution de la série, jamais avant : c'est elle qui permet de
            // reconstituer les jours précédents sur un appareil dont l'historique local
            // est vide (nouveau téléphone, réinstallation).
            StreakManager.recordVisit(streak: SharedDefaults.streakCount)

            // Le profil vit côté serveur : sur un nouvel appareil, on le restaure plutôt
            // que de redemander prénom et genre à quelqu'un qui les a déjà renseignés.
            if let firstName = result.profile.firstName, !firstName.isEmpty {
                SharedDefaults.firstName = firstName
                SharedDefaults.lastName = result.profile.lastName
                SharedDefaults.gender = result.profile.gender
                UserDefaults.standard.set(true, forKey: "hasCompletedProfile")
            }

            // Le quiz suit le même chemin que le profil. Sans cela, une réinstallation
            // reposait les questions à quelqu'un dont on venait de restaurer le prénom
            // sans le lui redemander — et le fil repartait sur des catégories neutres,
            // alors que le serveur savait lesquelles avaient été retenues.
            if let quizProfile = result.profile.quizProfile, !quizProfile.isEmpty {
                SharedDefaults.quizProfile = quizProfile
                if let categories = result.profile.preferredCategories, !categories.isEmpty {
                    SharedDefaults.preferredCategories = categories
                }
                UserDefaults.standard.set(true, forKey: "hasCompletedQuiz")
            }

            // Les réglages d'usage suivent le même chemin. Sans cela, une réinstallation
            // remettait silencieusement le rythme des notifications et les thèmes à leurs
            // valeurs par défaut : quelqu'un réglé sur deux citations par jour en recevait
            // trois sans avoir rien demandé.
            if let preferences = result.profile.preferences, !preferences.isEmpty {
                await applyRestored(preferences)
            }
        } else {
            favorites.detachSession()
            // Le blocage doit aussi s'appliquer avant connexion.
            await updateGate.refresh()
        }

        // Une seule fois par installation, pour tout compte connecté : couvre aussi bien
        // quelqu'un qui vient de créer son compte (déjà géré par OnboardingView, ce
        // deuxième appel n'y fait alors rien de plus) que quelqu'un déjà inscrit avant
        // l'existence de cette étape, ou dont le drapeau local a été perdu.
        // `enable()` ne redemande jamais si le système a déjà tranché — refusé ou
        // accepté — donc personne n'est resollicité à tort.
        if authManager.session != nil, !hasRequestedNotificationPermission {
            hasRequestedNotificationPermission = true
            await notificationManager.enable()
        }

        // À chaque ouverture, pas une seule fois : Apple change le jeton d'un appareil
        // à la réinstallation, à la restauration d'une sauvegarde, et parfois sans motif
        // apparent. Ne l'enregistrer qu'au premier lancement laisserait des appareils
        // injoignables sans que rien ne le signale.
        if authManager.session != nil {
            await PushRegistrar.registerIfAuthorized()
        }

        // Avant `reschedule()` : les notifications embarquent le texte de la citation au
        // moment où elles sont programmées. Rafraîchir après reviendrait à annoncer
        // pendant deux semaines une citation qu'on vient de corriger.
        await ContentSyncService.refreshIfNeeded()

        // Re-check StoreKit on every foreground: without this an expired or cancelled
        // subscription keeps unlocking premium content until the app is cold-launched.
        await store.refresh()
        await notificationManager.reschedule()

        // Série et historique sont désormais à jour : la célébration peut décider.
        router.streakRefreshTick += 1

        // Après `store.refresh()`, pour que l'évènement porte le bon état d'abonnement.
        Analytics.track(.appOpened, [
            "source": .string(router.consumeLaunchSource().rawValue),
            "streak": .int(SharedDefaults.streakCount),
            "favorites": .int(SharedDefaults.favoriteIDs.count),
            "notifications_on": .bool(SharedDefaults.notificationsEnabled)
        ])
    }

    /// Recopie les réglages restaurés depuis le serveur.
    ///
    /// L'autorisation de notifier est propre à l'appareil : le serveur retient que la
    /// personne en voulait, pas qu'iOS les accorde ici. On ne rallume donc le rythme que
    /// si l'autorisation tient encore — sinon l'écran des réglages afficherait un
    /// interrupteur allumé pendant qu'aucune notification n'arriverait jamais.
    private func applyRestored(_ preferences: UserSyncService.Preferences) async {
        if let theme = preferences.appTheme { appearance.appTheme = theme }
        if let cardTheme = preferences.cardTheme { appearance.cardTheme = cardTheme }
        if let frequency = preferences.notificationFrequency {
            SharedDefaults.notificationFrequency = frequency
        }

        let manager = NotificationManager()
        guard preferences.notificationsEnabled == true,
              await manager.isSystemAuthorized()
        else { return }

        SharedDefaults.notificationsEnabled = true
        // Le calendrier est reconstruit tout de suite : le rythme vient peut-être de
        // changer, et attendre la prochaine ouverture laisserait l'ancien en place.
        await manager.reschedule()
    }

    /// `signOut()` ne nettoyait rien en local : quelqu'un qui se connectait ensuite sur le
    /// même téléphone héritait des favoris, de la série et du prénom du compte précédent,
    /// et n'était même pas invité à saisir les siens puisque le profil était marqué
    /// terminé. On compare donc l'identifiant du compte à celui dont proviennent les
    /// données présentes, et on efface uniquement s'il a changé — se reconnecter avec le
    /// même compte ne fait donc rien reperdre.
    private func discardDataFromAnotherAccount(newUserID: String) {
        guard SharedDefaults.accountUserID != newUserID else { return }
        if SharedDefaults.accountUserID != nil {
            SharedDefaults.resetAccountData()
            UserDefaults.standard.removeObject(forKey: "hasCompletedProfile")
            UserDefaults.standard.removeObject(forKey: "hasCompletedQuiz")
            favorites.applyRemote(favoriteIDs: [])
        }
        SharedDefaults.accountUserID = newUserID
    }
}
