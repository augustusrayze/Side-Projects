import Foundation

struct LiturgicalDay: Identifiable {
    let id: UUID
    let date: Date
    let name: String            // "Easter Sunday"
    let liturgicalColor: String // "white", "red", "green", "purple", "rose"
    let isSolemnity: Bool
    let isFeast: Bool

    init(id: UUID = UUID(), date: Date, name: String, liturgicalColor: String,
         isSolemnity: Bool, isFeast: Bool) {
        self.id = id
        self.date = date
        self.name = name
        self.liturgicalColor = liturgicalColor
        self.isSolemnity = isSolemnity
        self.isFeast = isFeast
    }
}
