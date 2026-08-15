import SwiftUI

/// The one quote that's the same for every user on a given day — unlike the shuffled
/// feed below it, which is randomized per person and per launch.
struct DailyQuoteCard: View {
    let quote: Quote
    var isFavorite: Bool
    var onToggleFavorite: () -> Void
    var onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Citation du jour", systemImage: "sun.max.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: quote.category.symbolName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Text(quote.text)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
                .minimumScaleFactor(0.85)

            HStack(alignment: .bottom) {
                Text("— \(quote.author)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                HStack(spacing: 14) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .symbolEffect(.bounce, value: isFavorite)
                    .sensoryFeedback(.impact(weight: .medium), trigger: isFavorite)

                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
                .font(.title3)
                .foregroundStyle(.white)
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [quote.category.tint, .black.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: quote.category.tint.opacity(0.3), radius: 16, y: 8)
    }
}

#Preview {
    DailyQuoteCard(
        quote: ContentStore.allQuotes.first!,
        isFavorite: false,
        onToggleFavorite: {},
        onShare: {}
    )
    .padding()
}
