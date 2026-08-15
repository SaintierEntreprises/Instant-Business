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
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let notificationsEnabled = "notificationsEnabled"
        static let isPremium = "isPremium"
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

    static var notificationHour: Int {
        get { suite.object(forKey: Keys.notificationHour) as? Int ?? 8 }
        set { suite.set(newValue, forKey: Keys.notificationHour) }
    }

    static var notificationMinute: Int {
        get { suite.object(forKey: Keys.notificationMinute) as? Int ?? 0 }
        set { suite.set(newValue, forKey: Keys.notificationMinute) }
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
