import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var shareItem: ShareItem?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                if favorites.favoriteQuotes.isEmpty {
                    ContentUnavailableView(
                        "Aucun favori",
                        systemImage: "heart",
                        description: Text("Appuie sur le cœur d'une citation pour l'ajouter ici.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(favorites.favoriteQuotes) { quote in
                            QuoteCardView(
                                quote: quote,
                                isFavorite: true,
                                onToggleFavorite: { favorites.toggle(quote) },
                                onShare: { shareItem = ShareItem(quote: quote) }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Favoris")
            .sheet(item: $shareItem) { item in
                if let uiImage = ShareCardRenderer.uiImage(for: item.quote) {
                    ShareSheet(items: [uiImage, item.quote.text])
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesStore())
}
