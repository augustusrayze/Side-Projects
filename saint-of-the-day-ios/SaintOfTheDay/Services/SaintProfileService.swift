import Foundation

struct SaintProfileSectionRecord: Codable {
    let kind: SectionKind
    let heading: String
    let body: String
    let sourceTitle: String
    let sourceURL: String?
}

struct SaintProfileRecord: Codable {
    let canonicalName: String
    let aliases: [String]
    let shortBio: String?
    let timePeriod: String?
    let sections: [SaintProfileSectionRecord]
}

final class SaintProfileService {
    static let shared = SaintProfileService()

    private let records: [SaintProfileRecord]

    private init(bundle: Bundle = .main) {
        self.records = Self.loadRecords(bundle: bundle)
    }

    func profile(forNames names: [String]) -> SaintProfileRecord? {
        let normalizedNames = names.map(Self.normalize)
        for record in records {
            let candidates = [record.canonicalName] + record.aliases
            let normalizedCandidates = candidates.map(Self.normalize)
            if normalizedCandidates.contains(where: { candidate in
                normalizedNames.contains(candidate) || normalizedNames.contains(where: { $0.contains(candidate) || candidate.contains($0) })
            }) {
                return record
            }
        }
        return nil
    }

    func sections(forNames names: [String]) -> [SaintSection] {
        guard let profile = profile(forNames: names) else { return [] }
        return profile.sections.map {
            SaintSection(id: UUID(), kind: $0.kind, heading: $0.heading, body: $0.body)
        }
    }

    func shortBio(forNames names: [String]) -> String? {
        profile(forNames: names)?.shortBio?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func timePeriod(forNames names: [String]) -> String? {
        profile(forNames: names)?.timePeriod?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadRecords(bundle: Bundle) -> [SaintProfileRecord] {
        guard let url = bundle.url(forResource: "saint_profiles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([SaintProfileRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func normalize(_ value: String) -> String {
        let lowered = value.lowercased()
        let replaced = lowered
            .replacingOccurrences(of: "st.", with: "saint")
            .replacingOccurrences(of: "st ", with: "saint ")
            .folding(options: .diacriticInsensitive, locale: .current)
        let scalars = replaced.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " " ? Character(scalar) : " "
        }
        return String(scalars)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
