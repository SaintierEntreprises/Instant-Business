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
}
