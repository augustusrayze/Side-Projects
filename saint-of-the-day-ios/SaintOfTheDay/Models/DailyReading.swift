import Foundation

struct DailyReadings: Codable {
    let date: String
    let readings: [Reading]
}

struct Reading: Codable, Identifiable {
    let id: UUID
    let type: String       // "lecture1", "psaume", "lecture2", "evangile"
    let title: String      // "First Reading", "Psalm", etc.
    let reference: String  // "Acts 4:8-12"
    let text: String

    init(id: UUID = UUID(), type: String, title: String, reference: String, text: String) {
        self.id = id
        self.type = type
        self.title = title
        self.reference = reference
        self.text = text
    }
}
