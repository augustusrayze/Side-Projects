import Foundation

struct DailyPrayer: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let text: String
    let occasion: String
    let category: String
    let summary: String
    let sourceTitle: String
    let sourceURL: String?
    let weekdays: [Int]?
    let months: [Int]?
    let saintAliases: [String]
    let tags: [String]

    var sourceLink: URL? {
        guard let sourceURL else { return nil }
        return URL(string: sourceURL)
    }
}
