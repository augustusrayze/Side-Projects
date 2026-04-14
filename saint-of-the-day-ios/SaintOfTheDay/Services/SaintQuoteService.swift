import Foundation

struct SaintQuoteRecord: Codable {
    let canonicalName: String
    let aliases: [String]
    let quote: String
    let sourceTitle: String
    let sourceURL: String?
    let provenance: String
    let confidence: String
    let notes: String?
}

final class SaintQuoteService {
    static let shared = SaintQuoteService()

    private let records: [SaintQuoteRecord]

    private init(bundle: Bundle = .main) {
        self.records = Self.loadRecords(bundle: bundle)
    }

    func quote(forNames names: [String]) -> String? {
        record(forNames: names)?.quote
    }

    private func record(forNames names: [String]) -> SaintQuoteRecord? {
        let normalizedNames = names.map(Self.normalize).filter { !$0.isEmpty }

        return records
            .compactMap { record -> (score: Int, record: SaintQuoteRecord)? in
                let candidates = ([record.canonicalName] + record.aliases)
                    .map(Self.normalize)
                    .filter { !$0.isEmpty }

                var bestScore = 0
                for candidate in candidates {
                    for name in normalizedNames {
                        if name == candidate {
                            bestScore = max(bestScore, 100)
                        } else if name.contains(candidate) || candidate.contains(name) {
                            bestScore = max(bestScore, 60)
                        }
                    }
                }

                return bestScore > 0 ? (bestScore, record) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.record.canonicalName < rhs.record.canonicalName
                }
                return lhs.score > rhs.score
            }
            .first?
            .record
    }

    private static func loadRecords(bundle: Bundle) -> [SaintQuoteRecord] {
        guard let url = bundle.url(forResource: "saint_quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([SaintQuoteRecord].self, from: data) else {
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
