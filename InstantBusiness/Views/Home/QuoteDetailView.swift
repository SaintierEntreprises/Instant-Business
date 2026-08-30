import SwiftUI

/// Fiche d'une citation, ouverte en appuyant sur une carte.
///
/// La carte est faite pour frapper et pour se partager : gros texte, une couleur, rien
/// d'autre. Ce qu'elle ne peut pas porter, c'est ce qui rend une citation vraie plutôt
/// que jolie — qui l'a dite, quand, à quel propos. Cet écran-là existe pour ça, et
/// seulement à la demande : personne n'a envie d'une note de bas de page sur une carte
/// qu'il fait défiler.
///
/// Le contexte manque encore sur la plupart des citations, et c'est assumé — il se vérifie
/// une par une. L'écran ne montre alors que ce qu'il sait, et propose l'auteur : mieux vaut
/// une porte ouverte qu'un espace vide qui s'excuse.
struct QuoteDetailView: View {
    let quote: Quote

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var appearance: AppearanceStore
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?
    @State private var detent: PresentationDetent

    /// La hauteur d'ouverture dépend de ce qu'il y a à lire.
    ///
    /// Une citation sans contexte tient dans la moitié de l'écran ; avec le contexte, la
    /// moitié laisse justement sous la ligne de flottaison la seule chose qu'on est venu
    /// chercher. Décidé à la construction plutôt que dans `onAppear`, sinon la feuille
    /// s'ouvre petite puis grandit toute seule.
    init(quote: Quote) {
        self.quote = quote
        _detent = State(initialValue: quote.hasContext ? .large : .medium)
    }

    private var otherQuotesCount: Int {
        max(0, ContentStore.quotes(by: quote.author).count - 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(quote.category.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(quote.category.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(quote.category.tint.opacity(0.14), in: Capsule())

                    Text(quote.text)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)

                    Text("— \(quote.author)")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)

                    if let provenance = quote.provenance {
                        Text(provenance)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }

                    if let context = quote.context, !context.isEmpty {
                        contextBlock(context)
                            .padding(.top, 28)
                    }

                    actions
                        .padding(.top, 28)

                    if otherQuotesCount > 0 {
                        NavigationLink {
                            AuthorQuotesView(author: quote.author)
                        } label: {
                            authorLink
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.98))
                        .padding(.top, 12)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $shareItem) { item in
                if let image = ShareCardRenderer.uiImage(for: item.quote, theme: appearance.cardTheme) {
                    ShareSheet(items: [image])
                }
            }
        }
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // Sans fond explicite, la feuille laisse transparaître la carte de citation
        // restée derrière : un fond vert sous un texte de lecture, selon la catégorie de
        // ce qui se trouvait à cet endroit du carrousel.
        .presentationBackground(Color(.systemBackground))
        .onAppear {
            Haptics.prepare()
            SeenQuotes.record(quote.id)
            Analytics.track(.quoteOpened, [
                "quote_id": .string(quote.id),
                "category": .string(quote.category.rawValue),
                "has_context": .bool(quote.hasContext)
            ])
        }
    }

    private func contextBlock(_ context: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(quote.category.tint)
                Text("LE CONTEXTE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            Text(context)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                favorites.toggle(quote)
            } label: {
                Label(
                    favorites.isFavorite(quote) ? "Dans tes favoris" : "Ajouter aux favoris",
                    systemImage: favorites.isFavorite(quote) ? "heart.fill" : "heart"
                )
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(favorites.isFavorite(quote) ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(favorites.isFavorite(quote)
                              ? AnyShapeStyle(Color.pink.gradient)
                              : AnyShapeStyle(Color(.secondarySystemBackground)))
                )
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))

            Button {
                Haptics.tap()
                Analytics.trackShare(quote, origin: "detail")
                shareItem = ShareItem(quote: quote)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 52)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(PressableButtonStyle(scale: 0.94))
            .accessibilityLabel("Partager")
        }
    }

    private var authorLink: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(quote.category.tint.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text("\(otherQuotesCount) autre\(otherQuotesCount > 1 ? "s" : "") citation\(otherQuotesCount > 1 ? "s" : "") de \(quote.author)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    QuoteDetailView(quote: ContentStore.allQuotes.first!)
        .environmentObject(FavoritesStore())
        .environmentObject(AppearanceStore())
}
