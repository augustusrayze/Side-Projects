import Foundation

struct DailyPrayer: Codable, Identifiable {
    let id: String
    let name: String
    let text: String
    let occasion: String  // "Morning", "Evening", "Anytime", etc.
}
