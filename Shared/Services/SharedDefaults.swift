import Foundation

/// Thin wrapper over the App Group UserDefaults suite shared between the app and the widget extension.
enum SharedDefaults {
    static let appGroupID = "group.com.instantbusiness.app"
    static let suite = UserDefaults(suiteName: appGroupID) ?? .standard

    private enum Keys {
        static let favoriteIDs = "favoriteIDs"
        static let streakCount = "streakCount"
        static let lastOpenDate = "lastOpenDate"
        static let widgetTheme = "widgetTheme"
        static let widgetCategory = "widgetCategory"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationFrequency = "notificationFrequency"
        static let isPremium = "isPremium"
        static let cardTheme = "cardTheme"
        static let quizProfile = "quizProfile"
        static let preferredCategories = "preferredCategories"
        static let rotationSeed = "rotationSeed"
        static let rotationOffset = "rotationOffset"
        static let firstName = "firstName"
        static let lastName = "lastName"
        static let gender = "gender"
        static let accountUserID = "accountUserID"
        static let hasGrantedPremium = "hasGrantedPremium"
        static let lastForegroundDate = "lastForegroundDate"
        static let openDays = "openDays"
        static let dailyQuoteIDs = "dailyQuoteIDs"
        static let bestStreak = "bestStreak"
        static let lastStreakSheetDate = "lastStreakSheetDate"
        static let appTheme = "appTheme"
        static let frozenDays = "frozenDays"
        static let freezesRemaining = "freezesRemaining"
        static let freezePeriod = "freezePeriod"
        static let freezeGranted = "freezeGranted"
        static let lastFreezeDate = "lastFreezeDate"
        static let celebratedMilestone = "celebratedMilestone"
        static let lastContentSyncDate = "lastContentSyncDate"
        static let cachedContentBuild = "cachedContentBuild"
        static let seenQuoteIDs = "seenQuoteIDs"
        static let reviewPromptCount = "reviewPromptCount"
        static let lastReviewPromptDate = "lastReviewPromptDate"
    }

    // MARK: - Demande de note

    /// Nombre de fois où la feuille de notation a été demandée.
    ///
    /// Hors de `resetAccountData` comme le reste de ce bloc : le plafond d'iOS est par
    /// appareil, pas par compte. Se déconnecter ne doit pas remettre les compteurs à zéro
    /// et faire redemander une note à quelqu'un qui vient d'en donner une.
    static var reviewPromptCount: Int {
        get { suite.integer(forKey: Keys.reviewPromptCount) }
        set { suite.set(newValue, forKey: Keys.reviewPromptCount) }
    }

    static var lastReviewPromptDate: Date? {
        get { suite.object(forKey: Keys.lastReviewPromptDate) as? Date }
        set { suite.set(newValue, forKey: Keys.lastReviewPromptDate) }
    }

    /// Dernier rafraîchissement réussi du contenu depuis Supabase.
    ///
    /// Hors de `resetAccountData` : le contenu n'appartient à personne, changer de compte
    /// ne doit pas provoquer un retéléchargement de 573 citations.
    static var lastContentSyncDate: Date? {
        get { suite.object(forKey: Keys.lastContentSyncDate) as? Date }
        set { suite.set(newValue, forKey: Keys.lastContentSyncDate) }
    }

    /// Version de l'app qui a écrit la copie téléchargée du contenu.
    ///
    /// Une mise à jour peut apprendre à l'app un champ que la copie en cache ignore : le
    /// cache de la 1.2 ne contient ni « principe » ni « comment l'appliquer », que la
    /// 1.3 saurait pourtant afficher. Sans ce repère, l'app préférerait indéfiniment ce
    /// cache appauvri au JSON embarqué, plus complet, livré avec la mise à jour.
    static var cachedContentBuild: String? {
        get { suite.string(forKey: Keys.cachedContentBuild) }
        set { suite.set(newValue, forKey: Keys.cachedContentBuild) }
    }

    /// Version de l'app en cours d'exécution, `1.2 (31)`.
    ///
    /// Lue depuis `Bundle.main`, donc valable aussi bien dans l'app que dans le widget :
    /// les deux cibles partagent le même numéro de build.
    static var currentAppBuild: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - Citations déjà vues

    /// Identifiants déjà montrés dans le fil, du plus ancien au plus récent.
    ///
    /// Une liste ordonnée et non un ensemble : il faut pouvoir oublier les plus anciennes
    /// quand la liste déborde. Sans cette mémoire, le fil retombait sur les mêmes
    /// citations à quelques jours d'intervalle — le mélange est aléatoire, il n'a aucune
    /// raison d'éviter ce qui vient d'être lu.
    private static let seenQuoteLimit = 600

    static var seenQuoteIDs: [String] {
        get { suite.stringArray(forKey: Keys.seenQuoteIDs) ?? [] }
        set { suite.set(Array(newValue.suffix(seenQuoteLimit)), forKey: Keys.seenQuoteIDs) }
    }


    // MARK: - Jokers de série

    /// Jours sauvés par un joker, au même format que `openDays`.
    ///
    /// Tenus à part des jours ouverts, et pas seulement pour l'affichage : le
    /// remplissage rétroactif de `StreakManager.recordVisit` reconstitue les jours d'une
    /// série à partir de son compteur, or un jour gelé fait partie de la série sans avoir
    /// été ouvert. Les confondre reviendrait à prétendre que la personne était là.
    static var frozenDays: Set<String> {
        get { Set(suite.stringArray(forKey: Keys.frozenDays) ?? []) }
        set { suite.set(Array(newValue.sorted().suffix(openDaysLimit)), forKey: Keys.frozenDays) }
    }

    /// Jokers restants pour la période en cours.
    static var freezesRemaining: Int {
        get { suite.integer(forKey: Keys.freezesRemaining) }
        set { suite.set(max(0, newValue), forKey: Keys.freezesRemaining) }
    }

    /// Mois auquel se rapporte `freezesRemaining`, au format `yyyy-MM`. Un mois différent
    /// déclenche le réapprovisionnement.
    static var freezePeriod: String? {
        get { suite.string(forKey: Keys.freezePeriod) }
        set { suite.set(newValue, forKey: Keys.freezePeriod) }
    }

    /// Quota déjà accordé pour la période en cours, pour ne pas rejouer le complément
    /// premium à chaque ouverture.
    static var freezeGranted: Int {
        get { suite.integer(forKey: Keys.freezeGranted) }
        set { suite.set(newValue, forKey: Keys.freezeGranted) }
    }

    /// Jour effectivement sauvé par le dernier joker consommé, pour pouvoir l'annoncer.
    static var lastFreezeDate: Date? {
        get { suite.object(forKey: Keys.lastFreezeDate) as? Date }
        set { suite.set(newValue, forKey: Keys.lastFreezeDate) }
    }

    /// Dernier palier déjà fêté, pour ne pas rejouer la célébration à chaque ouverture du
    /// jour où il a été atteint.
    static var celebratedMilestone: Int {
        get { suite.integer(forKey: Keys.celebratedMilestone) }
        set { suite.set(newValue, forKey: Keys.celebratedMilestone) }
    }

    /// Apparence choisie pour l'interface. Absente — installation antérieure à ce
    /// réglage — vaut « Automatique », jamais une valeur imposée.
    static var appTheme: AppTheme {
        get { suite.string(forKey: Keys.appTheme).flatMap(AppTheme.init(rawValue:)) ?? .default }
        set { suite.set(newValue.rawValue, forKey: Keys.appTheme) }
    }

    // MARK: - Historique d'ouverture

    /// Jours d'ouverture au format `yyyy-MM-dd`, calendrier local.
    ///
    /// Le compteur de série seul ne suffit pas à dessiner une semaine : il dit combien de
    /// jours consécutifs tiennent aujourd'hui, pas quels jours ont été ouverts. Une série
    /// cassée mardi puis relancée jeudi laisserait lundi et mardi vides alors qu'ils ont
    /// bien été faits. On garde donc les jours eux-mêmes, sous la même forme que
    /// `last_open_date` côté serveur.
    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// L'opération inverse, pour relire un historique stocké sous forme de clés.
    static func date(fromDayKey key: String) -> Date? {
        dayKeyFormatter.date(from: key)
    }

    /// Conservés bien au-delà de la semaine affichée : la vue n'en montre que sept, mais
    /// garder un historique court permettrait plus tard un calendrier mensuel sans avoir
    /// à repartir de zéro. Tronqué pour que la liste ne grossisse pas indéfiniment.
    private static let openDaysLimit = 400

    /// Plafond du remplissage rétroactif, aligné sur la taille de l'historique conservé.
    static var openDaysLimitForBackfill: Int { openDaysLimit }

    static var openDays: Set<String> {
        get { Set(suite.stringArray(forKey: Keys.openDays) ?? []) }
        set {
            // Le format `yyyy-MM-dd` se trie alphabétiquement comme chronologiquement :
            // garder la fin de la liste triée revient à garder les jours les plus récents.
            let trimmed = newValue.sorted().suffix(openDaysLimit)
            suite.set(Array(trimmed), forKey: Keys.openDays)
        }
    }

    static func hasOpened(_ date: Date) -> Bool {
        openDays.contains(dayKey(for: date))
    }

    /// Citation du jour effectivement montrée, par journée.
    ///
    /// `ContentStore.quoteOfTheDay(on:)` sait recalculer n'importe quel jour passé, mais
    /// son résultat dépend du catalogue en vigueur : une citation corrigée ou retirée
    /// depuis réécrirait l'histoire, et le journal montrerait des citations que personne
    /// n'a jamais lues. On retient donc ce qui a été montré, et le recalcul ne sert plus
    /// que de secours pour les jours antérieurs à cette mémoire.
    ///
    /// Plafonné comme `openDays` : au-delà, un journal de plus d'un an n'a pas de lecteur.
    static var dailyQuoteIDs: [String: String] {
        get { suite.dictionary(forKey: Keys.dailyQuoteIDs) as? [String: String] ?? [:] }
        set {
            let trimmed = newValue.keys.sorted().suffix(openDaysLimit)
            suite.set(
                Dictionary(uniqueKeysWithValues: trimmed.map { ($0, newValue[$0]!) }),
                forKey: Keys.dailyQuoteIDs
            )
        }
    }

    /// Retient la citation montrée un jour donné, sans jamais écraser une entrée existante :
    /// la première version affichée est celle qui a été lue.
    static func rememberDailyQuote(id: String, on date: Date) {
        let key = dayKey(for: date)
        var all = dailyQuoteIDs
        guard all[key] == nil else { return }
        all[key] = id
        dailyQuoteIDs = all
    }

    /// Meilleure série atteinte, jamais redescendue. Sert de repère quand la série en
    /// cours repart de 1 : sans elle, une rechute efface toute trace de ce qui a été fait.
    /// Exposée pour permettre à une vue de s'y abonner via `@AppStorage`.
    static var bestStreakKey: String { Keys.bestStreak }

    static var bestStreak: Int {
        get { suite.integer(forKey: Keys.bestStreak) }
        set { suite.set(newValue, forKey: Keys.bestStreak) }
    }

    /// Dernier jour où la célébration de série a été montrée, pour ne l'afficher qu'une
    /// fois par jour.
    static var lastStreakSheetDate: Date? {
        get { suite.object(forKey: Keys.lastStreakSheetDate) as? Date }
        set { suite.set(newValue, forKey: Keys.lastStreakSheetDate) }
    }

    /// Dernier passage au premier plan, écrit à chaque ouverture.
    ///
    /// Distinct de `lastOpenDate`, que `StreakManager` compare pour calculer la série et
    /// qui ne doit donc pas être écrasé avant ce calcul. Sert uniquement à savoir quel
    /// jour l'app a réellement été ouverte, pour ne pas rappeler une série à quelqu'un
    /// qui vient de la sécuriser.
    static var lastForegroundDate: Date? {
        get { suite.object(forKey: Keys.lastForegroundDate) as? Date }
        set { suite.set(newValue, forKey: Keys.lastForegroundDate) }
    }

    /// Premium offert depuis Supabase, conservé en local pour rester valable hors ligne
    /// et entre deux synchronisations.
    static var hasGrantedPremium: Bool {
        get { suite.bool(forKey: Keys.hasGrantedPremium) }
        set { suite.set(newValue, forKey: Keys.hasGrantedPremium) }
    }

    /// Compte dont proviennent les données stockées ici, pour ne pas les servir à
    /// quelqu'un d'autre qui se connecterait sur le même téléphone.
    static var accountUserID: String? {
        get { suite.string(forKey: Keys.accountUserID) }
        set { suite.set(newValue, forKey: Keys.accountUserID) }
    }

    /// Prénom saisi après la connexion, aussi enregistré côté serveur.
    static var firstName: String? {
        get { suite.string(forKey: Keys.firstName) }
        set { suite.set(newValue, forKey: Keys.firstName) }
    }

    /// Nom de famille saisi après la connexion, aussi enregistré côté serveur.
    static var lastName: String? {
        get { suite.string(forKey: Keys.lastName) }
        set { suite.set(newValue, forKey: Keys.lastName) }
    }

    /// Genre, utilisé pour l'accord grammatical du profil et des salutations.
    static var gender: Gender? {
        get { suite.string(forKey: Keys.gender).flatMap(Gender.init(rawValue:)) }
        set { suite.set(newValue?.rawValue, forKey: Keys.gender) }
    }

    /// Nombre de crans dont la rotation a été avancée à la main, en plus de son
    /// avancement horaire naturel.
    ///
    /// Incrémenté à chaque ouverture de l'app depuis le widget : sans lui, on revenait
    /// à l'écran d'accueil pour y retrouver la citation qu'on venait justement de lire,
    /// et le widget paraissait figé. Appliqué au widget comme aux notifications, pour
    /// qu'ils continuent d'afficher la même chose au même instant.
    static var rotationOffset: Int {
        get { suite.integer(forKey: Keys.rotationOffset) }
        set { suite.set(newValue, forKey: Keys.rotationOffset) }
    }

    /// Per-installation random seed used to derive an hourly quote rotation that's
    /// stable across app/widget/notifications but different from one user to the next.
    static var rotationSeed: Int {
        if let existing = suite.object(forKey: Keys.rotationSeed) as? Int {
            return existing
        }
        let generated = Int.random(in: Int.min...Int.max)
        suite.set(generated, forKey: Keys.rotationSeed)
        return generated
    }

    static var cardTheme: CardTheme {
        get { CardTheme(rawValue: suite.string(forKey: Keys.cardTheme) ?? "") ?? .couleur }
        set { suite.set(newValue.rawValue, forKey: Keys.cardTheme) }
    }

    /// Profile label produced by the onboarding quiz (e.g. "Le Bâtisseur").
    static var quizProfile: String? {
        get { suite.string(forKey: Keys.quizProfile) }
        set { suite.set(newValue, forKey: Keys.quizProfile) }
    }

    /// Categories the quiz pre-selected for this user.
    static var preferredCategories: [QuoteCategory] {
        get { (suite.stringArray(forKey: Keys.preferredCategories) ?? []).compactMap(QuoteCategory.init(rawValue:)) }
        set { suite.set(newValue.map(\.rawValue), forKey: Keys.preferredCategories) }
    }

    static var favoriteIDs: Set<String> {
        get { Set(suite.stringArray(forKey: Keys.favoriteIDs) ?? []) }
        set { suite.set(Array(newValue), forKey: Keys.favoriteIDs) }
    }

    /// Exposée pour permettre à une vue de s'y abonner via `@AppStorage`.
    static var streakCountKey: String { Keys.streakCount }

    static var streakCount: Int {
        get { suite.integer(forKey: Keys.streakCount) }
        set { suite.set(newValue, forKey: Keys.streakCount) }
    }

    static var lastOpenDate: Date? {
        get { suite.object(forKey: Keys.lastOpenDate) as? Date }
        set { suite.set(newValue, forKey: Keys.lastOpenDate) }
    }

    static var widgetTheme: String {
        get { suite.string(forKey: Keys.widgetTheme) ?? "bold" }
        set { suite.set(newValue, forKey: Keys.widgetTheme) }
    }

    static var widgetCategory: QuoteCategory? {
        get { (suite.string(forKey: Keys.widgetCategory)).flatMap(QuoteCategory.init(rawValue:)) }
        set { suite.set(newValue?.rawValue, forKey: Keys.widgetCategory) }
    }

    static var notificationsEnabled: Bool {
        get { suite.bool(forKey: Keys.notificationsEnabled) }
        set { suite.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    /// Exposée pour permettre à une vue de s'y abonner via `@AppStorage`.
    static var notificationFrequencyKey: String { Keys.notificationFrequency }

    /// Rythme choisi par la personne. Absent — parce qu'elle s'est inscrite avant que ce
    /// choix existe — vaut le rythme par défaut, jamais l'ancien rythme nocturne.
    static var notificationFrequency: NotificationFrequency {
        get {
            suite.string(forKey: Keys.notificationFrequency)
                .flatMap(NotificationFrequency.init(rawValue:)) ?? .default
        }
        set { suite.set(newValue.rawValue, forKey: Keys.notificationFrequency) }
    }

    static var isPremium: Bool {
        get { suite.bool(forKey: Keys.isPremium) }
        set { suite.set(newValue, forKey: Keys.isPremium) }
    }

    /// Wipes everything tied to the account being deleted, so a fresh sign-in
    /// doesn't inherit a stranger's favorites, streak, or quiz profile.
    static func resetAccountData() {
        suite.removeObject(forKey: Keys.favoriteIDs)
        suite.removeObject(forKey: Keys.streakCount)
        suite.removeObject(forKey: Keys.lastOpenDate)
        suite.removeObject(forKey: Keys.isPremium)
        suite.removeObject(forKey: Keys.quizProfile)
        suite.removeObject(forKey: Keys.preferredCategories)
        suite.removeObject(forKey: Keys.cardTheme)
        suite.removeObject(forKey: Keys.firstName)
        suite.removeObject(forKey: Keys.lastName)
        suite.removeObject(forKey: Keys.gender)
        suite.removeObject(forKey: Keys.accountUserID)
        suite.removeObject(forKey: Keys.hasGrantedPremium)
        suite.removeObject(forKey: Keys.lastForegroundDate)
        suite.removeObject(forKey: Keys.openDays)
        suite.removeObject(forKey: Keys.dailyQuoteIDs)
        suite.removeObject(forKey: Keys.bestStreak)
        suite.removeObject(forKey: Keys.lastStreakSheetDate)
        suite.removeObject(forKey: Keys.frozenDays)
        suite.removeObject(forKey: Keys.freezesRemaining)
        suite.removeObject(forKey: Keys.freezePeriod)
        suite.removeObject(forKey: Keys.freezeGranted)
        suite.removeObject(forKey: Keys.lastFreezeDate)
        suite.removeObject(forKey: Keys.celebratedMilestone)
        suite.removeObject(forKey: Keys.seenQuoteIDs)
    }
}
