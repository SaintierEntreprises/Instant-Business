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

    static func quote(id: String) -> Quote? {
        allQuotes.first { $0.id == id }
    }

    /// Deterministic "quote of the day" so the app and the widget agree without shared state.
    static func quoteOfTheDay(category: QuoteCategory? = nil, on date: Date = Date()) -> Quote? {
        let pool = category.map(quotes(in:)) ?? allQuotes
        guard !pool.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % pool.count
        return pool[index]
    }
}
