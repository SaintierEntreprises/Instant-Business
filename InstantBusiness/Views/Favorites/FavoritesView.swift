import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var shareItem: ShareItem?
    var onDiscoverTapped: () -> Void = {}

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                if favorites.favoriteQuotes.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(favorites.favoriteQuotes) { quote in
                            QuoteCardView(
                                quote: quote,
                                isFavorite: true,
                                theme: appearance.cardTheme,
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text("Aucun favori pour l'instant")
                    .font(.headline)
                Text("Appuie sur le cœur d'une citation pour la retrouver ici.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onDiscoverTapped) {
                Text("Découvrir des citations")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
        }
        .padding(.top, 90)
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesStore())
        .environmentObject(AppearanceStore())
}
