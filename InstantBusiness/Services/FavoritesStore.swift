import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String>

    init() {
        favoriteIDs = SharedDefaults.favoriteIDs
    }

    func isFavorite(_ quote: Quote) -> Bool {
        favoriteIDs.contains(quote.id)
    }

    func toggle(_ quote: Quote) {
        if favoriteIDs.contains(quote.id) {
            favoriteIDs.remove(quote.id)
        } else {
            favoriteIDs.insert(quote.id)
        }
        SharedDefaults.favoriteIDs = favoriteIDs
    }

    var favoriteQuotes: [Quote] {
        ContentStore.allQuotes.filter { favoriteIDs.contains($0.id) }
    }
}
