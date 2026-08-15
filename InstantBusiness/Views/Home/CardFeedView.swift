import SwiftUI

struct CardFeedView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var focusedQuoteID: String?

    @State private var selectedCategory: QuoteCategory?
    @State private var displayedQuotes: [Quote] = []
    @State private var scrollPosition: String?
    @State private var shareItem: ShareItem?
    @State private var showPaywall = false
    @State private var streak = SharedDefaults.streakCount

    private var currentIndex: Int? {
        guard let scrollPosition else { return nil }
        return displayedQuotes.firstIndex { $0.id == scrollPosition }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                CategoryFilterBar(selectedCategory: $selectedCategory) { _ in
                    showPaywall = true
                }
                .padding(.top, 18)

                carousel
                    .padding(.top, 20)

                progressIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                reshuffle()
                streak = SharedDefaults.streakCount
            }
            .onChange(of: selectedCategory) { _, _ in reshuffle() }
            .onChange(of: focusedQuoteID) { _, id in focus(on: id) }
            .sheet(item: $shareItem) { item in
                if let uiImage = ShareCardRenderer.uiImage(for: item.quote) {
                    ShareSheet(items: [uiImage, "\(item.quote.text) — \(item.quote.author)"])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Instant Business")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                    Text("\(streak)")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.12), in: Capsule())
            }
        }
    }

    private var carousel: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 16) {
                    ForEach(displayedQuotes) { quote in
                        QuoteCardView(
                            quote: quote,
                            isFavorite: favorites.isFavorite(quote),
                            onToggleFavorite: { favorites.toggle(quote) },
                            onShare: { shareItem = ShareItem(quote: quote) }
                        )
                        .frame(width: proxy.size.width - 48)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                        }
                        .id(quote.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24)
            }
            // `.viewAligned` snaps to each card's own edges. `.paging` would advance by the
            // full viewport width instead, drifting further off-centre with every swipe.
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrollPosition)
        }
        .aspectRatio(0.78, contentMode: .fit)
    }

    private var progressIndicator: some View {
        Group {
            if let currentIndex {
                Text("\(currentIndex + 1) / \(displayedQuotes.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
                    .animation(.default, value: currentIndex)
            }
        }
        .frame(height: 16)
    }

    private func reshuffle() {
        let pool = selectedCategory.map(ContentStore.quotes(in:)) ?? ContentStore.allQuotes
        displayedQuotes = ContentStore.shuffledAvoidingAdjacentAuthors(pool)
        scrollPosition = displayedQuotes.first?.id
    }

    /// Brings a quote opened from the widget to the front of the feed.
    private func focus(on id: String?) {
        guard let id, let quote = ContentStore.quote(id: id) else { return }
        selectedCategory = nil
        var pool = ContentStore.shuffledAvoidingAdjacentAuthors(ContentStore.allQuotes)
        pool.removeAll { $0.id == id }
        displayedQuotes = [quote] + pool
        scrollPosition = id
        focusedQuoteID = nil
    }
}

#Preview {
    CardFeedView(focusedQuoteID: .constant(nil))
        .environmentObject(FavoritesStore())
        .environmentObject(StoreManager())
}
