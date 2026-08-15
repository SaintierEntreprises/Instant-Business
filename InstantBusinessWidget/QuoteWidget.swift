import WidgetKit
import SwiftUI

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote?
    let theme: WidgetTheme
}

struct QuoteTimelineProvider: AppIntentTimelineProvider {
    /// The lock-screen container only fits a few short lines, so it gets a shorter pool.
    private func maxLength(for family: WidgetFamily) -> Int? {
        switch family {
        case .accessoryRectangular, .accessoryInline: return 75
        case .systemSmall: return 110
        default: return nil
        }
    }

    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(
            date: Date(),
            quote: ContentStore.quoteOfTheDay(maxLength: maxLength(for: context.family)),
            theme: .gradient
        )
    }

    func snapshot(for configuration: QuoteWidgetConfigurationIntent, in context: Context) async -> QuoteEntry {
        QuoteEntry(
            date: Date(),
            quote: ContentStore.quoteOfTheDay(
                category: configuration.category.quoteCategory,
                maxLength: maxLength(for: context.family)
            ),
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
            quote: ContentStore.quoteOfTheDay(
                category: configuration.category.quoteCategory,
                maxLength: maxLength(for: context.family)
            ),
            theme: configuration.theme
        )
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct QuoteWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuoteEntry

    private var isAccessory: Bool {
        family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        Group {
            if let quote = entry.quote {
                content(for: quote)
                    .widgetURL(DeepLink.quoteURL(id: quote.id))
            } else {
                Text("Aucune citation")
                    .font(.caption)
            }
        }
        .containerBackground(for: .widget) {
            // Accessory (lock screen) widgets must stay transparent so they blend with
            // the wallpaper the way system widgets do.
            if isAccessory {
                Color.clear
            } else {
                ThemedWidgetBackground(theme: entry.theme, category: entry.quote?.category ?? .mindset)
            }
        }
    }

    @ViewBuilder
    private func content(for quote: Quote) -> some View {
        if isAccessory {
            LockScreenQuoteView(quote: quote)
        } else {
            ThemedQuoteView(quote: quote, theme: entry.theme, family: family)
        }
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}
