import Foundation

enum ContentStore {
    /// Contenu en vigueur : la copie téléchargée si elle existe, sinon celle du bundle.
    ///
    /// `var` et non plus `let` : le contenu vient désormais de Supabase et peut changer
    /// sans mise à jour de l'app. La mutation est réservée au processus de l'app, et au
    /// fil principal (voir `apply`) ; l'extension widget ne fait que lire, dans son propre
    /// processus, au moment où elle démarre.
    static private(set) var allQuotes: [Quote] = loadQuotes()

    /// Plancher de confiance pour un contenu téléchargé.
    ///
    /// Une réponse tronquée, une table vidée par erreur, un filtre malheureux : sans ce
    /// garde-fou, l'app remplacerait 573 citations par trois et n'aurait plus rien à
    /// montrer, y compris hors ligne. En dessous, on garde ce qu'on a.
    private static let minimumTrustedCount = 50

    /// Copie téléchargée, dans le conteneur partagé et non dans les Documents de l'app :
    /// le widget et l'extension de notifications doivent lire exactement le même contenu,
    /// sinon la citation annoncée sur l'écran d'accueil n'existerait plus dans l'app.
    static var cacheURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupID)?
            .appendingPathComponent("content-remote.json")
    }

    private static func loadQuotes() -> [Quote] {
        if let url = cacheURL,
           let data = try? Data(contentsOf: url),
           let quotes = try? JSONDecoder().decode([Quote].self, from: data),
           quotes.count >= minimumTrustedCount {
            return quotes
        }
        return bundledQuotes()
    }

    private static func bundledQuotes() -> [Quote] {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
            return []
        }
        return quotes
    }

    /// Remplace le contenu et les index dérivés. Retourne `false` si la liste proposée
    /// n'est pas crédible, auquel cas rien n'est touché.
    @discardableResult
    static func apply(remoteQuotes: [Quote]) -> Bool {
        guard remoteQuotes.count >= minimumTrustedCount else { return false }
        guard let url = cacheURL,
              let data = try? JSONEncoder().encode(remoteQuotes),
              (try? data.write(to: url, options: .atomic)) != nil
        else { return false }

        allQuotes = remoteQuotes
        rebuildIndexes()
        return true
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
    static private(set) var authors: [Author] = buildAuthors()

    private static var quotesByAuthor: [String: [Quote]] = Dictionary(grouping: allQuotes, by: \.author)

    /// Clé de recherche de chaque citation, calculée une fois.
    ///
    /// Replier 573 textes à chaque frappe rendait la saisie visiblement saccadée — le même
    /// problème, et la même réponse, que pour l'index des auteurs. La clé couvre le texte
    /// *et* l'auteur : chercher « buffett argent » doit fonctionner.
    private static var quoteSearchKeys: [(quote: Quote, key: String)] = buildQuoteSearchKeys()

    private static func buildAuthors() -> [Author] {
        Dictionary(grouping: allQuotes, by: \.author)
            .map { Author(name: $0.key, quoteCount: $0.value.count, searchKey: searchKey(for: $0.key)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func buildQuoteSearchKeys() -> [(quote: Quote, key: String)] {
        allQuotes.map { ($0, searchKey(for: "\($0.text) \($0.author)")) }
    }

    private static func rebuildIndexes() {
        clearCaches()
        authors = buildAuthors()
        quotesByAuthor = Dictionary(grouping: allQuotes, by: \.author)
        quotesByID = Dictionary(allQuotes.map { ($0.id, $0) }) { first, _ in first }
        quoteSearchKeys = buildQuoteSearchKeys()
    }

    static func quotes(by author: String) -> [Quote] {
        quotesByAuthor[author] ?? []
    }

    static func authors(matching query: String) -> [Author] {
        let key = searchKey(for: query)
        guard !key.isEmpty else { return authors }
        return authors.filter { $0.searchKey.contains(key) }
    }

    /// Citations dont le texte ou l'auteur contient la saisie.
    ///
    /// `limit` existe parce qu'une saisie d'une seule lettre remonte des centaines de
    /// résultats dont personne ne lira le dixième : au-delà, la liste ne rend plus service,
    /// elle rame.
    static func quotes(matching query: String, limit: Int = 60) -> [Quote] {
        let key = searchKey(for: query)
        guard !key.isEmpty else { return [] }
        var results: [Quote] = []
        for entry in quoteSearchKeys where entry.key.contains(key) {
            results.append(entry.quote)
            if results.count >= limit { break }
        }
        return results
    }

    private static func searchKey(for string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }

    private static var quotesByID: [String: Quote] = Dictionary(allQuotes.map { ($0.id, $0) }) { first, _ in first }

    static func quote(id: String) -> Quote? {
        quotesByID[id]
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

    /// Ordre du fil : d'abord ce qui n'a pas encore été vu, puis le reste.
    ///
    /// Le mélange seul n'a aucune raison d'éviter ce qu'on vient de lire : à trois
    /// citations par jour, quelqu'un d'assidu retombait sur les mêmes à quelques jours
    /// d'intervalle alors que des centaines n'avaient jamais été montrées.
    ///
    /// Les vues restent présentes à la suite plutôt que d'être retirées : une fois le
    /// stock épuisé, un fil qui se vide serait pire qu'un fil qui se répète.
    static func feedOrder(for quotes: [Quote], seen: Set<String>) -> [Quote] {
        let unseen = quotes.filter { !seen.contains($0.id) }
        guard !unseen.isEmpty, unseen.count < quotes.count else {
            return shuffledAvoidingAdjacentAuthors(quotes)
        }
        let alreadySeen = quotes.filter { seen.contains($0.id) }
        return shuffledAvoidingAdjacentAuthors(unseen) + shuffledAvoidingAdjacentAuthors(alreadySeen)
    }

    // MARK: - Mémoïsation

    /// Pools filtrés et ordres mélangés déjà calculés.
    ///
    /// Sans eux, chaque citation demandée refiltrait les 573 entrées puis mélangeait
    /// autant d'indices. Programmer une fenêtre de notifications en déclenche une
    /// quarantaine d'affilée, et `CardFeedView` en redéclenchait un à chaque
    /// reconstruction de sa vue — SwiftUI recrée la structure à chaque rendu du parent,
    /// or la citation du jour était calculée dans un stockage de propriété.
    ///
    /// Le tout est déterministe : mêmes entrées, même sortie. Le cache ne change donc
    /// aucun comportement, il évite seulement de refaire le même travail.
    private struct PoolKey: Hashable {
        let category: QuoteCategory?
        let maxLength: Int?
    }

    private struct OrderKey: Hashable {
        let seed: Int
        let pool: PoolKey
    }

    /// Le widget lit depuis son propre processus et son propre fil : deux écritures
    /// concurrentes dans un dictionnaire Swift ne se contentent pas de donner un résultat
    /// faux, elles font tomber le processus. Le verrou est sans conséquence sur les
    /// performances — il protège quelques lectures de dictionnaire.
    private static let cacheLock = NSLock()
    private static var poolCache: [PoolKey: [Quote]] = [:]
    private static var orderCache: [OrderKey: [Int]] = [:]
    private static var dailyCache: [String: Quote] = [:]

    private static func clearCaches() {
        cacheLock.lock()
        poolCache.removeAll()
        orderCache.removeAll()
        dailyCache.removeAll()
        cacheLock.unlock()
    }

    private static func pool(category: QuoteCategory?, maxLength: Int?) -> [Quote] {
        let key = PoolKey(category: category, maxLength: maxLength)
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = poolCache[key] { return cached }

        var result = category.map { cat in allQuotes.filter { $0.category == cat } } ?? allQuotes
        if let maxLength {
            let short = result.filter { $0.text.count <= maxLength }
            if !short.isEmpty { result = short }
        }
        poolCache[key] = result
        return result
    }

    private static func order(seed: Int, category: QuoteCategory?, maxLength: Int?, count: Int) -> [Int] {
        let key = OrderKey(seed: seed, pool: PoolKey(category: category, maxLength: maxLength))
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = orderCache[key] { return cached }

        var generator = SeededGenerator(seed: seed)
        let shuffled = Array(0..<count).shuffled(using: &generator)
        orderCache[key] = shuffled
        return shuffled
    }

    /// Deterministic "quote of the day" so the app and the widget agree without shared state.
    /// Uses a stable (non-hashValue-based) seeded shuffle so the daily sequence doesn't
    /// mirror the raw content order, where quotes are grouped by author.
    ///
    /// `maxLength` keeps the lock-screen widget readable: its container only fits a few
    /// short lines, so long quotes would be truncated mid-sentence.
    static func quoteOfTheDay(category: QuoteCategory? = nil, maxLength: Int? = nil, on date: Date = Date()) -> Quote? {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let cacheKey = "\(category?.rawValue ?? "all")-\(maxLength ?? 0)-\(dayOfYear)"

        cacheLock.lock()
        let cached = dailyCache[cacheKey]
        cacheLock.unlock()
        if let cached { return cached }

        let pool = pool(category: category, maxLength: maxLength)
        guard !pool.isEmpty else { return nil }

        let seed = stableHash("\(category?.rawValue ?? "all")-\(maxLength ?? 0)")
        let order = order(seed: seed, category: category, maxLength: maxLength, count: pool.count)
        let quote = pool[order[dayOfYear % order.count]]

        cacheLock.lock()
        dailyCache[cacheKey] = quote
        cacheLock.unlock()
        return quote
    }

    /// Per-user rotating quote: `seed` (one random value per installation) picks a fixed
    /// shuffle order for the pool, and `unit` (e.g. an hour count) walks through it. Same
    /// (seed, unit) always yields the same quote, so the widget and the notification
    /// scheduler agree on "what's showing right now" without sharing any other state.
    static func rotatingQuote(seed: Int, unit: Int, category: QuoteCategory? = nil, maxLength: Int? = nil) -> Quote? {
        let pool = pool(category: category, maxLength: maxLength)
        guard !pool.isEmpty else { return nil }

        let effectiveSeed = stableHash("\(seed)-\(category?.rawValue ?? "all")-\(maxLength ?? 0)")
        let order = order(seed: effectiveSeed, category: category, maxLength: maxLength, count: pool.count)
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
