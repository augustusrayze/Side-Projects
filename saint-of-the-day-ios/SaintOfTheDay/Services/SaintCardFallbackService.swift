import Foundation

struct SaintCardFallbackRecord: Codable {
    let canonicalName: String
    let aliases: [String]
    let shortBio: String?
    let quote: String?
    let patronages: String?
}

final class SaintCardFallbackService {
    static let shared = SaintCardFallbackService()

    private let records: [SaintCardFallbackRecord]

    private init(bundle: Bundle = .main) {
        self.records = Self.loadRecords(bundle: bundle)
    }

    func shortBio(forNames names: [String]) -> String? {
        record(forNames: names)?.shortBio?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func quote(forNames names: [String]) -> String? {
        record(forNames: names)?.quote?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func patronages(forNames names: [String]) -> String? {
        record(forNames: names)?.patronages?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func record(forNames names: [String]) -> SaintCardFallbackRecord? {
        let normalizedNames = names.map(Self.normalize).filter { !$0.isEmpty }

        return records.first { record in
            let candidates = ([record.canonicalName] + record.aliases)
                .map(Self.normalize)
                .filter { !$0.isEmpty }

            return candidates.contains { candidate in
                normalizedNames.contains(candidate) || normalizedNames.contains(where: { $0.contains(candidate) || candidate.contains($0) })
            }
        }
    }

    private static func loadRecords(bundle: Bundle) -> [SaintCardFallbackRecord] {
        guard let url = bundle.url(forResource: "saint_card_fallbacks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([SaintCardFallbackRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "st.", with: "saint")
            .replacingOccurrences(of: "st ", with: "saint ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
