import SwiftUI

struct CardFeedView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var selectedCategory: QuoteCategory?
    @State private var displayedQuotes: [Quote] = []
    @State private var selectedQuoteID: String?
    @State private var shareItem: ShareItem?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                CategoryFilterBar(selectedCategory: $selectedCategory) { _ in
                    showPaywall = true
                }

                TabView(selection: $selectedQuoteID) {
                    ForEach(displayedQuotes) { quote in
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
            .onAppear { reshuffle() }
            .onChange(of: selectedCategory) { _, _ in reshuffle() }
            .sheet(item: $shareItem) { item in
                if let uiImage = ShareCardRenderer.uiImage(for: item.quote) {
                    ShareSheet(items: [uiImage, item.quote.text])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func reshuffle() {
        let pool = selectedCategory.map(ContentStore.quotes(in:)) ?? ContentStore.allQuotes
        displayedQuotes = ContentStore.shuffledAvoidingAdjacentAuthors(pool)
        selectedQuoteID = displayedQuotes.first?.id
    }
}

#Preview {
    CardFeedView()
        .environmentObject(FavoritesStore())
        .environmentObject(StoreManager())
}
