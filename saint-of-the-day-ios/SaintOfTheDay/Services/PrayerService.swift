import Foundation

final class PrayerService {
    static let shared = PrayerService()

    private let prayers: [DailyPrayer]

    private init(bundle: Bundle = .main) {
        self.prayers = Self.loadPrayers(bundle: bundle)
    }

    var library: [DailyPrayer] {
        prayers
    }

    var categories: [String] {
        var seen = Set<String>()
        return prayers.compactMap { prayer in
            guard seen.insert(prayer.category).inserted else {
                return nil
            }
            return prayer.category
        }
    }

    func prayer(for date: Date, saintName: String? = nil) -> DailyPrayer? {
        guard !prayers.isEmpty else { return nil }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let month = calendar.component(.month, from: date)
        let normalizedSaint = saintName.map(Self.normalize)

        let scored = prayers.map { prayer -> (score: Int, prayer: DailyPrayer) in
            var score = 0

            if let weekdays = prayer.weekdays, weekdays.contains(weekday) {
                score += 20
            }

            if let months = prayer.months, months.contains(month) {
                score += 14
            }

            if let normalizedSaint, !prayer.saintAliases.isEmpty {
                let aliases = prayer.saintAliases.map(Self.normalize)
                if aliases.contains(where: { normalizedSaint.contains($0) || $0.contains(normalizedSaint) }) {
                    score += 30
                }
            }

            if prayer.weekdays == nil && prayer.months == nil && prayer.saintAliases.isEmpty {
                score += 4
            }

            return (score, prayer)
        }

        let bestScore = scored.map(\.score).max() ?? 0
        let candidates = scored.filter { $0.score == bestScore }.map(\.prayer)
        let dayOrdinal = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return candidates[dayOrdinal % candidates.count]
    }

    func prayer(withID id: String) -> DailyPrayer? {
        prayers.first { $0.id == id }
    }

    private static func loadPrayers(bundle: Bundle) -> [DailyPrayer] {
        guard let url = bundle.url(forResource: "prayers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DailyPrayer].self, from: data) else {
            return []
        }
        return decoded
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
