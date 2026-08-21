import SwiftUI

struct CardFeedView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var store: StoreManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didApplyQuizPreference = false
    @Binding var focusedQuoteID: String?

    @State private var selectedCategory: QuoteCategory?
    @State private var displayedQuotes: [Quote] = []
    @State private var scrollPosition: String?
    @State private var shareItem: ShareItem?
    @State private var showPaywall = false
    @State private var streak = SharedDefaults.streakCount

    /// Same quote for every user on a given day — independent of the shuffled feed below.
    private let dailyQuote = ContentStore.quoteOfTheDay()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    if let dailyQuote {
                        DailyQuoteCard(
                            quote: dailyQuote,
                            isFavorite: favorites.isFavorite(dailyQuote),
                            theme: appearance.cardTheme,
                            onToggleFavorite: { favorites.toggle(dailyQuote) },
                            onShare: { shareItem = ShareItem(quote: dailyQuote) }
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }

                    Text("DÉCOUVRIR")
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 10)

                    CategoryFilterBar(selectedCategory: $selectedCategory) { _ in
                        showPaywall = true
                    }

                    carousel
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                applyQuizPreferenceIfNeeded()
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
                Text(SharedDefaults.firstName.map { "Salut \($0)" } ?? "Instant Business")
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
        // Read once here: the scroll transition closure is Sendable and can't
        // reach back into main-actor state.
        let reduceMotion = reduceMotion
        return GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 16) {
                    ForEach(displayedQuotes) { quote in
                        QuoteCardView(
                            quote: quote,
                            isFavorite: favorites.isFavorite(quote),
                            theme: appearance.cardTheme,
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

    /// Pre-selects the category the quiz favoured — but only when it's actually usable,
    /// so a free user is never dropped onto a locked category.
    private func applyQuizPreferenceIfNeeded() {
        guard !didApplyQuizPreference else { return }
        didApplyQuizPreference = true
        guard selectedCategory == nil,
              let preferred = SharedDefaults.preferredCategories.first,
              preferred == .mindset || store.isPremium
        else { return }
        selectedCategory = preferred
    }

    private func reshuffle() {
        let pool = selectedCategory.map(ContentStore.quotes(in:)) ?? ContentStore.allQuotes
        var shuffled = ContentStore.shuffledAvoidingAdjacentAuthors(pool)
        // Avoid showing the daily quote twice — it already has its own spot above.
        if let dailyQuote {
            shuffled.removeAll { $0.id == dailyQuote.id }
        }
        displayedQuotes = shuffled
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
        .environmentObject(AppearanceStore())
}
