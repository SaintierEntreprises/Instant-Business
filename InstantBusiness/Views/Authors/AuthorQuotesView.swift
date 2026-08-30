import SwiftUI

/// Toutes les citations d'un auteur, groupées par catégorie.
///
/// Mise en page éditoriale plutôt qu'une grille de cartes colorées : à deux colonnes, des
/// cartes de hauteurs inégales se décalent en quinconce et se lisent comme une mise en
/// page ratée. Les cartes servent à découvrir et à partager ; cette page-ci sert à lire
/// une œuvre, d'où la colonne unique, la typographie large et la couleur réduite à un
/// accent de catégorie.
struct AuthorQuotesView: View {
    let author: String

    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var store: StoreManager
    @State private var shareItem: ShareItem?
    @State private var detailQuote: Quote?
    @State private var showPaywall = false

    private var quotes: [Quote] { ContentStore.quotes(by: author) }

    /// Groupes dans l'ordre de `QuoteCategory.allCases`, catégories vides écartées.
    private var sections: [(category: QuoteCategory, quotes: [Quote])] {
        QuoteCategory.allCases.compactMap { category in
            let matching = quotes.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    private var unlockedSections: [(category: QuoteCategory, quotes: [Quote])] {
        sections.filter { !isLocked($0.category) }
    }

    private var lockedSections: [(category: QuoteCategory, quotes: [Quote])] {
        sections.filter { isLocked($0.category) }
    }

    private var lockedCount: Int {
        lockedSections.reduce(0) { $0 + $1.quotes.count }
    }

    /// Même règle que la barre de filtres du fil : Mindset est ouvert, le reste est
    /// Premium. Sans cela, cette page distribuerait gratuitement ce que le paywall vend.
    private func isLocked(_ category: QuoteCategory) -> Bool {
        category != .mindset && !store.isPremium
    }

    /// Teinte dominante de l'auteur, reprise dans l'insigne d'en-tête : Sénèque tire vers
    /// l'orange du mindset, Buffett vers le vert de la finance.
    private var dominantTint: Color {
        let counts = Dictionary(grouping: quotes, by: \.category).mapValues(\.count)
        let top = QuoteCategory.allCases.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
        return (top ?? .mindset).tint
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14, pinnedViews: []) {
                header
                    .padding(.bottom, 2)

                ForEach(unlockedSections, id: \.category) { section in
                    sectionHeader(section.category, count: section.quotes.count)

                    ForEach(section.quotes) { quote in
                        row(for: quote)
                    }
                }

                if !lockedSections.isEmpty {
                    lockedCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(author)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            if let uiImage = ShareCardRenderer.uiImage(for: item.quote) {
                ShareSheet(items: [uiImage, "\(item.quote.text) — \(item.quote.author)"])
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(origin: "author_page")
        }
        .sheet(item: $detailQuote) { quote in
            QuoteDetailView(quote: quote)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(initials)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(
                    LinearGradient(
                        colors: [dominantTint, dominantTint.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: dominantTint.opacity(0.3), radius: 16, y: 8)

            Text(author)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .tracking(-0.4)
                .multilineTextAlignment(.center)

            Text("\(quotes.count) citation\(quotes.count > 1 ? "s" : "")")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func sectionHeader(_ category: QuoteCategory, count: Int) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(category.tint)
                .frame(width: 7, height: 7)

            Text(category.displayName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(category.tint)

            Spacer(minLength: 0)

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
    }

    /// Un seul encart pour toutes les catégories verrouillées.
    ///
    /// Un encart par catégorie, comme dans la première version, empilait jusqu'à trois
    /// blocs quasi identiques à la suite — chez Branson, qui couvre les quatre catégories,
    /// ça se lisait comme du harcèlement plutôt que comme une offre. Le détail par
    /// catégorie reste visible ici, mais il n'y a qu'un seul appel à l'action, et le
    /// total cumulé est plus convaincant que trois petits nombres séparés.
    ///
    /// Placé après les citations lisibles : la personne vient de lire un auteur qu'elle
    /// apprécie et voit précisément ce qui lui manque chez lui — bien meilleur moment
    /// qu'un écran générique.
    private var lockedCard: some View {
        Button {
            Haptics.tap()
            showPaywall = true
        } label: {
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                Text("\(lockedCount) autre\(lockedCount > 1 ? "s" : "") citation\(lockedCount > 1 ? "s" : "") de \(author)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    ForEach(lockedSections, id: \.category) { section in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(section.category.tint)
                                .frame(width: 6, height: 6)
                            Text(section.category.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text("\(section.quotes.count)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)

                Text("Voir l'offre")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Color.accentColor, in: Capsule())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .padding(.top, 14)
    }

    private func row(for quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(quote.text)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Spacer(minLength: 0)

                FavoriteHeartButton(
                    isFavorite: favorites.isFavorite(quote),
                    iconFont: .system(size: 18),
                    hitSize: 38,
                    action: { favorites.toggle(quote) }
                )

                Button {
                    Haptics.tap()
                    Analytics.trackShare(quote, origin: "author_page")
                    shareItem = ShareItem(quote: quote)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
            .foregroundStyle(.secondary)
            .padding(.trailing, -6)
            .padding(.bottom, -8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            detailQuote = quote
        }
    }

    private var initials: String {
        author.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}
