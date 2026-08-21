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
        static let isPremium = "isPremium"
        static let cardTheme = "cardTheme"
        static let quizProfile = "quizProfile"
        static let preferredCategories = "preferredCategories"
        static let rotationSeed = "rotationSeed"
        static let firstName = "firstName"
        static let lastName = "lastName"
        static let gender = "gender"
        static let accountUserID = "accountUserID"
        static let hasGrantedPremium = "hasGrantedPremium"
        static let lastForegroundDate = "lastForegroundDate"
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
    }
}
