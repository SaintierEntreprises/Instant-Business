import SwiftUI

struct QuoteCardView: View {
    let quote: Quote
    var isFavorite: Bool = false
    var showControls: Bool = true
    var onToggleFavorite: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [quote.category.tint.opacity(0.95), quote.category.tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 20) {
                Label(quote.category.displayName, systemImage: quote.category.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Text(quote.text)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if showControls {
                    HStack(spacing: 16) {
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(28)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
    }
}

#Preview {
    QuoteCardView(quote: ContentStore.allQuotes.first!, isFavorite: false)
        .padding()
}
