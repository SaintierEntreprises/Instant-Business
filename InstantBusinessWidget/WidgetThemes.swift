import SwiftUI

struct ThemedQuoteView: View {
    let quote: Quote
    let theme: WidgetTheme

    var body: some View {
        ZStack {
            background
            content
        }
    }

    @ViewBuilder
    private var background: some View {
        switch theme {
        case .bold:
            quote.category.tint
        case .minimal:
            Color(.systemBackground)
        case .gradient:
            LinearGradient(
                colors: [quote.category.tint, .black.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            Color.black
        }
    }

    private var textColor: Color {
        theme == .minimal ? .primary : .white
    }

    private var secondaryColor: Color {
        theme == .minimal ? .secondary : .white.opacity(0.75)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if theme == .minimal {
                Capsule()
                    .fill(quote.category.tint)
                    .frame(width: 28, height: 4)
            }
            Spacer()
            Text(quote.text)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.6)
                .lineLimit(5)
            Text("— \(quote.author)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryColor)
        }
        .padding()
    }
}

struct LockScreenQuoteView: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(quote.text)
                .font(.caption.weight(.semibold))
                .lineLimit(3)
            Text(quote.author)
                .font(.caption2)
                .opacity(0.7)
        }
    }
}
