import AppIntents

enum WidgetCategoryOption: String, CaseIterable, AppEnum {
    case all
    case mindset
    case sales
    case leadership
    case finance

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Catégorie"

    static var caseDisplayRepresentations: [WidgetCategoryOption: DisplayRepresentation] = [
        .all: "Toutes",
        .mindset: "Mindset & Motivation",
        .sales: "Vente & Marketing",
        .leadership: "Leadership",
        .finance: "Argent & Finance"
    ]

    var quoteCategory: QuoteCategory? {
        switch self {
        case .all: return nil
        case .mindset: return .mindset
        case .sales: return .sales
        case .leadership: return .leadership
        case .finance: return .finance
        }
    }
}

struct QuoteWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Citation du jour"
    static var description = IntentDescription("Choisis la catégorie et le style de ta citation.")

    @Parameter(title: "Catégorie", default: .all)
    var category: WidgetCategoryOption

    @Parameter(title: "Thème", default: .gradient)
    var theme: WidgetTheme
}
