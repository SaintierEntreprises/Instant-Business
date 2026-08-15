import SwiftUI

struct CardFeedView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: QuoteCategory?
    @State private var displayedQuotes: [Quote] = []
    @State private var scrollPosition: String?
    @State private var shareItem: ShareItem?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                CategoryFilterBar(selectedCategory: $selectedCategory) { _ in
                    showPaywall = true
                }

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 20) {
                        ForEach(displayedQuotes) { quote in
                            QuoteCardView(
                                quote: quote,
                                isFavorite: favorites.isFavorite(quote),
                                onToggleFavorite: { favorites.toggle(quote) },
                                onShare: { shareItem = ShareItem(quote: quote) }
                            )
                            .padding(.horizontal, 4)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                            .containerRelativeFrame(.horizontal, count: 1, spacing: 20)
                            .id(quote.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 24, for: .scrollContent)
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrollPosition)
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxHeight: 520)

                Spacer(minLength: 0)
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
        scrollPosition = displayedQuotes.first?.id
    }
}

#Preview {
    CardFeedView()
        .environmentObject(FavoritesStore())
        .environmentObject(StoreManager())
}
