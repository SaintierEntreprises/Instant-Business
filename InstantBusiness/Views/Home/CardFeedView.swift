import SwiftUI

struct CardFeedView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var selectedCategory: QuoteCategory?
    @State private var selectedQuoteID: String?
    @State private var shareItem: ShareItem?

    private var quotes: [Quote] {
        guard let selectedCategory else { return ContentStore.allQuotes }
        return ContentStore.quotes(in: selectedCategory)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                CategoryFilterBar(selectedCategory: $selectedCategory)

                TabView(selection: $selectedQuoteID) {
                    ForEach(quotes) { quote in
                        QuoteCardView(
                            quote: quote,
                            isFavorite: favorites.isFavorite(quote),
                            onToggleFavorite: { favorites.toggle(quote) },
                            onShare: { shareItem = ShareItem(quote: quote) }
                        )
                        .padding(.horizontal, 24)
                        .tag(quote.id as String?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Instant Business")
            .sheet(item: $shareItem) { item in
                if let uiImage = ShareCardRenderer.uiImage(for: item.quote) {
                    ShareSheet(items: [uiImage, item.quote.text])
                }
            }
        }
    }
}

#Preview {
    CardFeedView()
        .environmentObject(FavoritesStore())
}
