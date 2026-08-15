import Foundation

struct Quote: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let author: String
    let category: QuoteCategory
}
