import WidgetKit
import SwiftUI

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote?
    let theme: WidgetTheme
}

struct QuoteTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: ContentStore.allQuotes.first, theme: .gradient)
    }

    func snapshot(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> QuoteEntry {
        QuoteEntry(
            date: Date(),
            quote: ContentStore.quoteOfTheDay(category: configuration.category.quoteCategory),
            theme: configuration.theme
        )
    }

    func timeline(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> Timeline<QuoteEntry> {
        let calendar = Calendar.current
        let now = Date()
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(86_400)
        let noon = calendar.nextDate(after: now, matching: DateComponents(hour: 12, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(43_200)
        let nextRefresh = min(midnight, noon)

        let entry = QuoteEntry(
            date: now,
            quote: ContentStore.quoteOfTheDay(category: configuration.category.quoteCategory),
            theme: configuration.theme
        )
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct QuoteWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuoteEntry

    var body: some View {
        Group {
            if let quote = entry.quote {
                if family == .accessoryRectangular {
                    LockScreenQuoteView(quote: quote)
                } else {
                    ThemedQuoteView(quote: quote, theme: entry.theme)
                }
            } else {
                Text("Aucune citation")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct QuoteWidget: Widget {
    let kind: String = "QuoteWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuoteWidgetConfigurationIntent.self, provider: QuoteTimelineProvider()) { entry in
            QuoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Citation du jour")
        .description("Une citation business inspirante sur ton écran d'accueil ou de verrouillage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}
