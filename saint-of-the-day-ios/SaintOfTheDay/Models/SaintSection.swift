import Foundation

enum SectionKind: String, Codable, Hashable {
    case biography
    case miracles
    case writings
    case patronages
    case canonization
    case other
}

struct SaintSection: Codable, Identifiable, Hashable {
    let id: UUID
    let kind: SectionKind
    let heading: String
    let body: String
}
