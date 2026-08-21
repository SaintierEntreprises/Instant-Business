import SwiftUI
import UIKit

struct QuoteCardView: View {
    let quote: Quote
    var isFavorite: Bool = false
    var showControls: Bool = true
    /// Réservé à l'image partagée. Dans l'app, la signature n'aurait aucun sens — on sait
    /// déjà où on est — et elle occuperait la place des commandes.
    var showSignature: Bool = false
    var theme: CardTheme = SharedDefaults.cardTheme
    var onToggleFavorite: () -> Void = {}
    var onShare: () -> Void = {}
    var onAuthorTapped: (() -> Void)?

    /// Largeur d'une carte pleine largeur sur iPhone, à laquelle toutes les tailles
    /// ci-dessous sont calibrées.
    private static let referenceWidth: CGFloat = 354

    /// Une taille fixe laissait un grand vide au milieu des cartes portant une citation
    /// courte, alors que ce sont justement les plus percutantes. Le texte grossit donc
    /// pour occuper la carte quand il est court, et rétrécit quand il est long.
    private var baseTextSize: CGFloat {
        switch quote.text.count {
        case ..<60: return 32
        case ..<110: return 27
        case ..<170: return 23
        default: return 19
        }
    }

    var body: some View {
        // La même carte sert en pleine largeur dans le fil et en demi-largeur dans les
        // grilles (favoris, page auteur). Sans mise à l'échelle, la taille calibrée pour
        // le fil rendait le texte démesuré dans une colonne deux fois plus étroite.
        GeometryReader { proxy in
            card(scale: proxy.size.width / Self.referenceWidth)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .shadow(color: theme.shadowColor(for: quote.category), radius: 20, y: 12)
    }

    private func card(scale: CGFloat) -> some View {
        let textSize = baseTextSize * scale

        return ZStack {
            theme.background(for: quote.category)

            Text("“")
                .font(.system(size: 170 * scale, weight: .black))
                .foregroundStyle(theme.watermarkColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 4 * scale)
                .padding(.top, -20 * scale)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 20 * scale) {
                Text(quote.category.displayName.uppercased())
                    .font(.system(size: max(8, 11 * scale), weight: .bold))
                    .tracking(0.6 * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(theme.pillForeground(for: quote.category))
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(theme.pillBackground(for: quote.category), in: Capsule())

                Spacer(minLength: 0)

                Text(quote.text)
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
                    // Crénage resserré sur les grandes tailles, relâché sur les petites :
                    // à 32 pt les lettres paraissent trop espacées, à 19 pt trop serrées.
                    .tracking(textSize > 26 ? -0.6 : 0)
                    .lineSpacing(textSize > 26 ? 1 : 2)
                    .foregroundStyle(theme.textColor)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                authorLabel(scale: scale)

                Spacer(minLength: 0)

                if showSignature { signature(scale: scale) }

                if showControls { controls(scale: scale) }
            }
            .padding(28 * scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .stroke(theme.borderColor, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func authorLabel(scale: CGFloat) -> some View {
        let label = Text("— \(quote.author)")
            .font(.system(size: max(10, 15 * scale), weight: .medium))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .foregroundStyle(theme.secondaryTextColor)

        if let onAuthorTapped {
            Button {
                Haptics.tap()
                onAuthorTapped()
            } label: {
                label
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
        } else {
            label
        }
    }

    private func controls(scale: CGFloat) -> some View {
        // La zone tactile ne descend pas avec l'échelle : en demi-largeur elle deviendrait
        // trop petite pour être visée au pouce.
        let hitSize = max(34, 44 * scale)

        return HStack(spacing: 16 * scale) {
            FavoriteHeartButton(
                isFavorite: isFavorite,
                iconFont: .system(size: max(16, 22 * scale)),
                hitSize: hitSize,
                action: onToggleFavorite
            )

            Button {
                Haptics.tap()
                onShare()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: max(16, 22 * scale)))
                    .frame(width: hitSize, height: hitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.textColor)
    }

    /// Signature de la carte partagée.
    ///
    /// Volontairement minuscule et à faible contraste : une carte estampillée d'un gros
    /// logo ne se partage pas, et une carte que personne ne partage ne ramène personne.
    /// Elle doit se lire si on la cherche, et disparaître si on ne la cherche pas.
    private func signature(scale: CGFloat) -> some View {
        HStack(spacing: 5 * scale) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 11 * scale))
            Text("Instant Business")
                .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                .tracking(0.2 * scale)
        }
        .foregroundStyle(theme.secondaryTextColor.opacity(0.55))
    }
}

#Preview {
    QuoteCardView(quote: ContentStore.allQuotes.first!, isFavorite: false)
        .padding()
}
