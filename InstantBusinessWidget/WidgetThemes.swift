import SwiftUI
import WidgetKit

/// Home-screen background. Lives in `containerBackground` so iOS can extend it edge to edge.
struct ThemedWidgetBackground: View {
    let theme: WidgetTheme
    let category: QuoteCategory

    var body: some View {
        switch theme {
        case .bold:
            category.tint
        case .minimal:
            Color(.systemBackground)
        case .gradient:
            // Composited over black: fading the tint's own opacity avoids the washed-out
            // grey a direct tint→black interpolation produces.
            ZStack {
                Color.black
                LinearGradient(
                    colors: [category.tint, category.tint.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .dark:
            LinearGradient(
                colors: [Color(white: 0.14), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct ThemedQuoteView: View {
    let quote: Quote
    let theme: WidgetTheme
    var family: WidgetFamily = .systemMedium

    private var textColor: Color {
        theme == .minimal ? .primary : .white
    }

    private var secondaryColor: Color {
        theme == .minimal ? .secondary : .white.opacity(0.75)
    }

    private var quoteFont: Font {
        switch family {
        case .systemSmall: return .system(size: 14, weight: .bold, design: .rounded)
        case .systemLarge: return .system(size: 24, weight: .bold, design: .rounded)
        default: return .system(size: 17, weight: .bold, design: .rounded)
        }
    }

    private var lineLimit: Int {
        switch family {
        case .systemSmall: return 6
        case .systemLarge: return 12
        default: return 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 6) {
            if family != .systemSmall {
                HStack(spacing: 5) {
                    Image(systemName: quote.category.symbolName)
                        .font(.system(size: 9, weight: .bold))
                    Text(quote.category.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.4)
                }
                .foregroundStyle(theme == .minimal ? quote.category.tint : .white.opacity(0.8))
            }

            Spacer(minLength: 0)

            Text(quote.text)
                .font(quoteFont)
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.55)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(quote.author)
                .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Lock-screen rendering: no background of its own, tinted by the system to match the wallpaper.
struct LockScreenQuoteView: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(quote.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.65)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(quote.author)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .opacity(0.65)
                .lineLimit(1)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
