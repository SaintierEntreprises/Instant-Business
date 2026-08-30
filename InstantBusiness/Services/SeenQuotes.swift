import Foundation

/// Tampon des citations vues, vidé par à-coups plutôt qu'à chaque carte.
///
/// La version précédente écrivait dans les préférences partagées à chaque fois qu'une
/// carte s'arrêtait au centre du carrousel : relecture d'un tableau de 600 identifiants,
/// recherche linéaire, réécriture — pendant le geste de défilement, sur le fil principal.
/// Ce n'est pas ce qui fait tomber une image, mais c'est du travail synchrone posé
/// exactement au pire endroit, et il n'y avait aucune raison de le faire là.
///
/// L'écriture est donc regroupée : les identifiants s'accumulent en mémoire et ne
/// descendent sur disque qu'une fois le défilement calmé, ou quand l'app passe en
/// arrière-plan. Perdre le tampon serait sans conséquence — au pire une citation
/// réapparaît une fois de plus.
@MainActor
enum SeenQuotes {
    private static var pending: [String] = []
    private static var flushTask: Task<Void, Never>?

    /// Assez long pour couvrir un enchaînement de cartes, assez court pour que rien ne se
    /// perde si l'app est tuée juste après.
    private static let flushDelay: Duration = .seconds(2)

    static func record(_ id: String) {
        if let existing = pending.firstIndex(of: id) {
            pending.remove(at: existing)
        }
        pending.append(id)

        flushTask?.cancel()
        flushTask = Task {
            try? await Task.sleep(for: flushDelay)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    static func flush() {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending = []
        flushTask?.cancel()
        flushTask = nil

        var seen = SharedDefaults.seenQuoteIDs
        for id in batch {
            if let existing = seen.firstIndex(of: id) {
                seen.remove(at: existing)
            }
            seen.append(id)
        }
        SharedDefaults.seenQuoteIDs = seen
    }

    /// Ce que le fil doit considérer comme déjà vu : le disque et ce qui n'y est pas
    /// encore descendu. Sans le tampon, un mélange déclenché juste après un défilement
    /// remonterait les cartes qu'on vient de faire passer.
    static func all() -> Set<String> {
        Set(SharedDefaults.seenQuoteIDs).union(pending)
    }
}
