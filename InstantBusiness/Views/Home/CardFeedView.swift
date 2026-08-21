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
    @State private var suppressesScrollFeedback = true

    /// Lu via `@AppStorage` sur la suite partagée, et non copié dans un `@State` au moment
    /// de l'apparition : la synchronisation serveur arrive après, et la valeur affichée
    /// restait donc celle d'avant — le plus souvent 0 au premier lancement.
    @AppStorage(SharedDefaults.streakCountKey, store: SharedDefaults.suite)
    private var streak = 0

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
            // Sans barre de navigation, le contenu défilait à nu sous la barre d'état et
            // le texte des cartes passait derrière l'encoche. Un fondu vers le fond, sans
            // trait de séparation, sépare les deux sans alourdir l'écran.
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemBackground).opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 56)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .onAppear {
                Haptics.prepare()
                applyQuizPreferenceIfNeeded()
                // L'identifiant peut déjà être posé quand le fil apparaît, si l'app vient
                // d'être lancée depuis le widget ou une notification. Mélanger d'abord
                // écraserait la citation demandée.
                if let focusedQuoteID {
                    focus(on: focusedQuoteID)
                } else {
                    reshuffle()
                }
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
                .contentTransition(.numericText())
                .transition(.scale.combined(with: .opacity))
            }
        }
        // La série arrive après la synchronisation : elle doit se poser, pas surgir.
        .animation(.spring(response: 0.45, dampingFraction: 1), value: streak)
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
                                .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.90)
                                .opacity(phase.isIdentity ? 1 : 0.45)
                                // La carte résiste légèrement au défilement : le décalage
                                // inverse crée une parallaxe entre elle et le geste, et
                                // c'est ce qui donne l'impression d'une épaisseur.
                                .offset(x: reduceMotion ? 0 : phase.value * -14)
                                .rotation3DEffect(
                                    .degrees(reduceMotion ? 0 : phase.value * -5),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.4
                                )
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
            // Un cran à chaque carte franchie. Filtré pendant les repositionnements
            // programmés (mélange, ouverture depuis le widget), qui déplacent aussi
            // `scrollPosition` sans que l'utilisateur ait rien fait.
            .sensoryFeedback(.selection, trigger: scrollPosition) { previous, current in
                guard !suppressesScrollFeedback, let previous, let current else { return false }
                return previous != current
            }
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
        jump(to: displayedQuotes.first?.id)
    }

    /// Repositionne le carrousel sans déclencher le retour haptique du défilement, qui
    /// n'a de sens que quand c'est la personne qui fait glisser la carte.
    private func jump(to id: String?) {
        suppressesScrollFeedback = true
        scrollPosition = id
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            suppressesScrollFeedback = false
        }
    }

    /// Brings a quote opened from the widget to the front of the feed.
    private func focus(on id: String?) {
        guard let id, let quote = ContentStore.quote(id: id) else { return }
        selectedCategory = nil
        var pool = ContentStore.shuffledAvoidingAdjacentAuthors(ContentStore.allQuotes)
        pool.removeAll { $0.id == id }
        displayedQuotes = [quote] + pool
        jump(to: id)
        focusedQuoteID = nil
    }
}

#Preview {
    CardFeedView(focusedQuoteID: .constant(nil))
        .environmentObject(FavoritesStore())
        .environmentObject(StoreManager())
        .environmentObject(AppearanceStore())
}
