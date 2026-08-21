import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String>

    private let syncService = UserSyncService()
    private var userID: String?

    init() {
        favoriteIDs = SharedDefaults.favoriteIDs
    }

    func isFavorite(_ quote: Quote) -> Bool {
        favoriteIDs.contains(quote.id)
    }

    func toggle(_ quote: Quote) {
        let isNowFavorite: Bool
        if favoriteIDs.contains(quote.id) {
            favoriteIDs.remove(quote.id)
            isNowFavorite = false
        } else {
            favoriteIDs.insert(quote.id)
            isNowFavorite = true
        }
        SharedDefaults.favoriteIDs = favoriteIDs

        Analytics.track(isNowFavorite ? .quoteFavorited : .quoteUnfavorited, [
            "quote_id": .string(quote.id),
            "category": .string(quote.category.rawValue),
            "author": .string(quote.author),
            "total": .int(favoriteIDs.count)
        ])

        if let userID {
            Task { await syncService.toggleFavorite(userID: userID, quoteID: quote.id, isFavorite: isNowFavorite) }
        }
    }

    var favoriteQuotes: [Quote] {
        ContentStore.allQuotes.filter { favoriteIDs.contains($0.id) }
    }

    /// Called once per sign-in/foreground when a session exists — the server is authoritative.
    func attachSession(userID: String) {
        self.userID = userID
    }

    func detachSession() {
        userID = nil
    }

    func applyRemote(favoriteIDs: Set<String>) {
        self.favoriteIDs = favoriteIDs
        SharedDefaults.favoriteIDs = favoriteIDs
    }
}
