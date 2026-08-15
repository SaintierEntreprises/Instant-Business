import Foundation

/// Links the widget back into the app, so tapping a quote opens it directly.
enum DeepLink {
    static let scheme = "instantbusiness"
    private static let quoteHost = "quote"

    static func quoteURL(id: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = quoteHost
        components.path = "/\(id)"
        return components.url
    }

    /// Returns the quote id when `url` is a quote deep link, otherwise nil.
    static func quoteID(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == quoteHost else { return nil }
        let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return id.isEmpty ? nil : id
    }
}
