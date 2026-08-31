import SwiftUI

/// Carte destinée à être exportée en image et partagée hors de l'app.
///
/// Distincte de `QuoteCardView` parce que leurs contraintes s'opposent. Dans le fil, la
/// carte est un objet posé sur un fond : coins arrondis, ombre portée, commandes. Partagée,
/// elle devient l'image entière — les coins arrondis y laissent des angles transparents
/// qu'Instagram compose sur son propre fond, et l'ombre n'a plus rien sur quoi tomber.
///
/// Le format 4:5 est le seul que toutes les destinations acceptent sans recadrer :
/// c'est le maximum vertical d'une publication Instagram, et une story le centre en
/// prolongeant les bords — ce que le fond à bords perdus rend invisible.
struct QuoteShareCard: View {
    let quote: Quote
    var theme: CardTheme = SharedDefaults.cardTheme

    /// Dimensions de conception. Rendues à l'échelle 2, elles donnent 1080 × 1350, la
    /// définition qu'Instagram attend sans rééchantillonner.
    static let size = CGSize(width: 540, height: 675)

    /// Une citation partagée se regarde d'abord en vignette, dans un fil qui défile. Les
    /// tailles sont donc plus généreuses que dans l'app, où le texte est déjà à portée de
    /// lecture.
    private var textSize: CGFloat {
        switch quote.text.count {
        case ..<60: return 54
        case ..<110: return 45
        case ..<170: return 37
        default: return 31
        }
    }

    private var padding: CGFloat { 54 }

    var body: some View {
        ZStack {
            theme.background(for: quote.category)

            // Halo décentré : sans lui, un aplat de couleur sorti en 1080 × 1350 paraît
            // plat et bon marché. Il ne se voit pas, il se sent.
            RadialGradient(
                colors: [.white.opacity(theme.isLight ? 0.35 : 0.14), .clear],
                center: UnitPoint(x: 0.22, y: 0.12),
                startRadius: 0,
                endRadius: Self.size.width * 1.1
            )

            VStack(alignment: .leading, spacing: 0) {
                categoryPill

                Spacer(minLength: 28)

                quotationMark

                Text(quote.text)
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
                    .tracking(textSize > 40 ? -0.8 : -0.3)
                    .lineSpacing(textSize * 0.14)
                    .foregroundStyle(theme.textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.top, 22)

                Spacer(minLength: 28)

                signature
            }
            // Sans largeur imposée, la pile se réduit à son plus large enfant et se
            // retrouve centrée : une citation courte produisait une colonne étroite au
            // milieu de l'image, alors qu'une longue remplissait la largeur et paraissait
            // correctement calée. Le défaut ne se voyait donc que sur certaines citations.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        // Ni coins arrondis ni bordure : l'image partagée n'est pas posée sur quelque
        // chose, elle est le fond.
        .clipped()
    }

    private var categoryPill: some View {
        Text(quote.category.displayName.uppercased())
            .font(.system(size: 15, weight: .bold))
            .tracking(1.1)
            .lineLimit(1)
            .foregroundStyle(theme.pillForeground(for: quote.category))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.pillBackground(for: quote.category), in: Capsule())
    }

    /// Guillemet posé au-dessus du texte plutôt qu'en filigrane derrière lui.
    ///
    /// Dans l'app il déborde du coin, à demi coupé : le regard glisse dessus. Sorti en
    /// image et regardé pour lui-même, ce fragment se lit comme un défaut de cadrage.
    /// Entier et aligné sur le texte, il donne au contraire un point d'appui à la
    /// composition.
    private var quotationMark: some View {
        Text("“")
            .font(.system(size: 96, weight: .black, design: .serif))
            .foregroundStyle(theme.textColor.opacity(theme.isLight ? 0.16 : 0.28))
            // Le glyphe porte une avance latérale et une hauteur de ligne qui le
            // décolleraient du texte : on les reprend pour l'aligner optiquement.
            .frame(height: 52, alignment: .top)
            .offset(x: -6)
            .padding(.bottom, 10)
    }

    /// Signature du bas.
    ///
    /// Plus présente que dans l'app — c'est la seule chose qui ramène quelqu'un depuis une
    /// story — mais elle reste une signature : une carte estampillée comme une publicité
    /// ne se partage pas, et une carte que personne ne partage ne ramène personne.
    private var signature: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 17, weight: .semibold))
            Text("Instant Business")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .tracking(0.3)
        }
        .foregroundStyle(theme.secondaryTextColor.opacity(0.75))
    }
}

#Preview {
    QuoteShareCard(quote: ContentStore.allQuotes.first!)
}
