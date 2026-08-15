import SwiftUI
import UIKit

struct QuoteCardView: View {
    let quote: Quote
    var isFavorite: Bool = false
    var showControls: Bool = true
    var onToggleFavorite: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [quote.category.tint.opacity(0.95), quote.category.tint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text("“")
                .font(.system(size: 170, weight: .black))
                .foregroundStyle(.white.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 4)
                .padding(.top, -20)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 20) {
                Text(quote.category.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: Capsule())

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
                        .buttonStyle(.pressable)
                        .symbolEffect(.bounce, value: isFavorite)
                        .sensoryFeedback(.impact(weight: .medium), trigger: isFavorite)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)

                        Spacer()
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .shadow(color: quote.category.tint.opacity(0.35), radius: 20, y: 12)
    }
}

#Preview {
    QuoteCardView(quote: ContentStore.allQuotes.first!, isFavorite: false)
        .padding()
}
