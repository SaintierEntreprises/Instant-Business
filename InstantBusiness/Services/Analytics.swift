import Foundation
import Supabase

/// Journal d'évènements envoyé vers Supabase.
///
/// Trois règles tenues partout :
/// - **Jamais bloquant.** Chaque envoi part dans une tâche détachée et son échec est
///   avalé. Une mesure ne doit jamais ralentir ni casser ce que la personne est en train
///   de faire.
/// - **Jamais de contenu personnel.** On enregistre des identifiants de citation et des
///   noms de catégorie, jamais un prénom, un nom, une adresse e-mail ni un texte saisi.
/// - **Rien avant la connexion.** La table exige `auth.uid()`, donc un évènement sans
///   session est simplement ignoré plutôt que de partir en erreur.
@MainActor
enum Analytics {
    // MARK: - Noms d'évènements

    enum Event: String {
        case appOpened = "app_opened"
        case quoteFavorited = "quote_favorited"
        case quoteUnfavorited = "quote_unfavorited"
        case quoteShared = "quote_shared"
        case quoteOpened = "quote_opened"
        case quoteSearched = "quote_searched"
        case authorOpened = "author_opened"
        case authorSearched = "author_searched"
        case categorySelected = "category_selected"
        case lockedCategoryTapped = "locked_category_tapped"
        case paywallShown = "paywall_shown"
        case paywallDismissed = "paywall_dismissed"
        case purchaseStarted = "purchase_started"
        case purchaseCompleted = "purchase_completed"
        case purchaseFailed = "purchase_failed"
        case notificationOpened = "notification_opened"
        case widgetOpened = "widget_opened"
        case notificationsEnabled = "notifications_enabled"
        case notificationsDisabled = "notifications_disabled"
        case notificationFrequencyChanged = "notification_frequency_changed"
        case onboardingCompleted = "onboarding_completed"
        case profileCompleted = "profile_completed"
        case quizCompleted = "quiz_completed"
        case cardThemeChanged = "card_theme_changed"
        case appThemeChanged = "app_theme_changed"
        case accountDeleted = "account_deleted"
        case streakSheetShown = "streak_sheet_shown"
        case streakMilestoneReached = "streak_milestone_reached"
        case streakShared = "streak_shared"
        case streakFreezeUsed = "streak_freeze_used"
        case reviewPromptShown = "review_prompt_shown"
        case reviewLinkOpened = "review_link_opened"
    }

    /// D'où vient l'ouverture de l'app. Sans cette distinction, impossible de dire si les
    /// notifications servent réellement à quelque chose.
    enum Source: String {
        case direct
        case notification
        case widget
    }

    // MARK: - Envoi

    private struct Row: Encodable {
        let user_id: String
        let name: String
        let properties: [String: AnyEncodableValue]
        let app_version: String
        let is_premium: Bool
    }

    /// Renseigné au lancement pour que chaque évènement porte l'état d'abonnement du
    /// moment, sans que chaque appelant ait à le passer.
    static var isPremiumProvider: () -> Bool = { SharedDefaults.isPremium }

    /// Raccourci pour le partage, qui part de quatre écrans différents et doit toujours
    /// enregistrer les mêmes champs.
    static func trackShare(_ quote: Quote, origin: String) {
        track(.quoteShared, [
            "quote_id": .string(quote.id),
            "category": .string(quote.category.rawValue),
            "author": .string(quote.author),
            "origin": .string(origin)
        ])
    }

    static func track(_ event: Event, _ properties: [String: AnyEncodableValue] = [:]) {
        guard let userID = SupabaseProvider.client.auth.currentUser?.id.uuidString else { return }

        let row = Row(
            user_id: userID,
            name: event.rawValue,
            properties: properties,
            app_version: AppUpdateGate.installedVersion,
            is_premium: isPremiumProvider()
        )

        Task.detached {
            _ = try? await SupabaseProvider.client
                .from("events")
                .insert(row)
                .execute()
        }
    }
}

/// Valeur de propriété, limitée aux types qu'on veut vraiment voir passer.
///
/// Un `[String: Any]` ne serait pas encodable, et un `[String: String]` obligerait à
/// convertir chaque nombre en chaîne — ce qui rendrait toute agrégation SQL pénible.
enum AnyEncodableValue: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

extension AnyEncodableValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .string(value) }
}

extension AnyEncodableValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self = .int(value) }
}

extension AnyEncodableValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) { self = .bool(value) }
}
