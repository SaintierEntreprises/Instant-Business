import Foundation

enum ContentStore {
    static let allQuotes: [Quote] = loadQuotes()

    private static func loadQuotes() -> [Quote] {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
            return []
        }
        return quotes
    }

    static func quotes(in category: QuoteCategory) -> [Quote] {
        allQuotes.filter { $0.category == category }
    }

    // MARK: - Auteurs

    struct Author: Identifiable, Hashable {
        let name: String
        let quoteCount: Int
        /// Nom réduit en minuscules sans accent ni ponctuation, comparé tel quel à la
        /// saisie : « senequ » doit trouver « Sénèque », et « stjobs » ne doit rien
        /// trouver plutôt que de renvoyer n'importe quoi.
        let searchKey: String

        var id: String { name }
    }

    /// Index construit une seule fois au premier accès, et non à chaque frappe : trier
    /// 285 auteurs à chaque caractère saisi rendait la liste visiblement saccadée.
    ///
    /// Ordre alphabétique : dans une liste de cette longueur, c'est le seul classement où
    /// l'on sait d'avance où regarder. `localizedStandardCompare` place « Sénèque » sous
    /// S et non après Z, contrairement à une comparaison brute de chaînes.
    static let authors: [Author] = {
        Dictionary(grouping: allQuotes, by: \.author)
            .map { Author(name: $0.key, quoteCount: $0.value.count, searchKey: searchKey(for: $0.key)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()

    private static let quotesByAuthor: [String: [Quote]] = Dictionary(grouping: allQuotes, by: \.author)

    static func quotes(by author: String) -> [Quote] {
        quotesByAuthor[author] ?? []
    }

    static func authors(matching query: String) -> [Author] {
        let key = searchKey(for: query)
        guard !key.isEmpty else { return authors }
        return authors.filter { $0.searchKey.contains(key) }
    }

    private static func searchKey(for string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }

    static func quote(id: String) -> Quote? {
        allQuotes.first { $0.id == id }
    }

    /// Random order, but never two quotes from the same author back to back.
    static func shuffledAvoidingAdjacentAuthors(_ quotes: [Quote]) -> [Quote] {
        var buckets: [String: [Quote]] = [:]
        for quote in quotes {
            buckets[quote.author, default: []].append(quote)
        }
        for key in buckets.keys {
            buckets[key]?.shuffle()
        }

        var result: [Quote] = []
        result.reserveCapacity(quotes.count)
        var lastAuthor: String?

        while result.count < quotes.count {
            let candidates = buckets.keys.filter { !(buckets[$0]?.isEmpty ?? true) }
            guard !candidates.isEmpty else { break }
            let preferred = candidates.filter { $0 != lastAuthor }
            let pool = preferred.isEmpty ? candidates : preferred
            guard let author = pool.randomElement(), var bucket = buckets[author], let quote = bucket.popLast() else { break }
            buckets[author] = bucket
            result.append(quote)
            lastAuthor = author
        }

        return result
    }

    /// Deterministic "quote of the day" so the app and the widget agree without shared state.
    /// Uses a stable (non-hashValue-based) seeded shuffle so the daily sequence doesn't
    /// mirror the raw content order, where quotes are grouped by author.
    ///
    /// `maxLength` keeps the lock-screen widget readable: its container only fits a few
    /// short lines, so long quotes would be truncated mid-sentence.
    static func quoteOfTheDay(category: QuoteCategory? = nil, maxLength: Int? = nil, on date: Date = Date()) -> Quote? {
        var pool = category.map(quotes(in:)) ?? allQuotes
        if let maxLength {
            let short = pool.filter { $0.text.count <= maxLength }
            if !short.isEmpty { pool = short }
        }
        guard !pool.isEmpty else { return nil }

        var generator = SeededGenerator(seed: stableHash("\(category?.rawValue ?? "all")-\(maxLength ?? 0)"))
        let order = pool.indices.shuffled(using: &generator)

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = order[dayOfYear % order.count]
        return pool[index]
    }

    /// Per-user rotating quote: `seed` (one random value per installation) picks a fixed
    /// shuffle order for the pool, and `unit` (e.g. an hour count) walks through it. Same
    /// (seed, unit) always yields the same quote, so the widget and the notification
    /// scheduler agree on "what's showing right now" without sharing any other state.
    static func rotatingQuote(seed: Int, unit: Int, category: QuoteCategory? = nil, maxLength: Int? = nil) -> Quote? {
        var pool = category.map(quotes(in:)) ?? allQuotes
        if let maxLength {
            let short = pool.filter { $0.text.count <= maxLength }
            if !short.isEmpty { pool = short }
        }
        guard !pool.isEmpty else { return nil }

        var generator = SeededGenerator(seed: stableHash("\(seed)-\(category?.rawValue ?? "all")-\(maxLength ?? 0)"))
        let order = pool.indices.shuffled(using: &generator)
        let index = order[((unit % order.count) + order.count) % order.count]
        return pool[index]
    }

    /// Number of whole hours since a fixed epoch — a stable, ever-increasing "hour slot"
    /// shared by anyone computing it for the same instant.
    static func hourSlot(for date: Date = Date()) -> Int {
        Int(date.timeIntervalSince1970 / 3600)
    }

    /// Position dans la rotation à un instant donné : le créneau horaire, plus les crans
    /// avancés à la main (voir `SharedDefaults.rotationOffset`).
    ///
    /// Point d'entrée unique pour le widget et le planificateur de notifications : c'est
    /// ce qui garantit qu'ils montrent la même citation au même moment, y compris après
    /// un avancement manuel.
    static func rotationUnit(for date: Date = Date()) -> Int {
        hourSlot(for: date) + SharedDefaults.rotationOffset
    }

    /// Avance la rotation d'un cran. Appelé quand quelqu'un ouvre l'app depuis le widget :
    /// la citation qu'il vient de lire laisse la place à la suivante.
    static func advanceRotation() {
        SharedDefaults.rotationOffset += 1
    }

    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(truncatingIfNeeded: hash)
    }
}

/// Deterministic RNG (splitmix64) so the same seed always produces the same sequence,
/// unlike Swift's built-in hashValue which is randomized per process.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
