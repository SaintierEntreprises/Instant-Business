import SwiftUI
import UIKit

struct QuoteCardView: View {
    let quote: Quote
    var isFavorite: Bool = false
    var showControls: Bool = true
    var theme: CardTheme = SharedDefaults.cardTheme
    var onToggleFavorite: () -> Void = {}
    var onShare: () -> Void = {}

    /// Une taille fixe laissait un grand vide au milieu des cartes portant une citation
    /// courte, alors que ce sont justement les plus percutantes. Le texte grossit donc
    /// pour occuper la carte quand il est court, et rétrécit quand il est long.
    private var textSize: CGFloat {
        switch quote.text.count {
        case ..<60: return 32
        case ..<110: return 27
        case ..<170: return 23
        default: return 19
        }
    }

    var body: some View {
        ZStack {
            theme.background(for: quote.category)

            Text("“")
                .font(.system(size: 170, weight: .black))
                .foregroundStyle(theme.watermarkColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 4)
                .padding(.top, -20)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 20) {
                Text(quote.category.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(theme.pillForeground(for: quote.category))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.pillBackground(for: quote.category), in: Capsule())

                Spacer()

                Text(quote.text)
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
                    // Crénage resserré sur les grandes tailles, relâché sur les petites :
                    // à 32 pt les lettres paraissent trop espacées, à 19 pt trop serrées.
                    .tracking(textSize > 26 ? -0.6 : 0)
                    .lineSpacing(textSize > 26 ? 1 : 2)
                    .foregroundStyle(theme.textColor)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryTextColor)

                Spacer()

                if showControls {
                    HStack(spacing: 16) {
                        FavoriteHeartButton(isFavorite: isFavorite, action: onToggleFavorite)

                        Button {
                            Haptics.tap()
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
                    .foregroundStyle(theme.textColor)
                }
            }
            .padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .shadow(color: theme.shadowColor(for: quote.category), radius: 20, y: 12)
    }
}

#Preview {
    QuoteCardView(quote: ContentStore.allQuotes.first!, isFavorite: false)
        .padding()
}
