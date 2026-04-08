import Foundation

final class LiturgicalCalendarService {

    static let shared = LiturgicalCalendarService()
    private init() {}

    // MARK: - Public API

    func fetchCalendar(for year: Int) async throws -> [LiturgicalDay] {
        let key = "litcal-\(year).json"
        if let cached = loadFromCache(key: key) { return cached }

        let days = try await fetchFromNetwork(year: year)
        saveToCache(days, key: key)
        return days
    }

    func currentSeason(from days: [LiturgicalDay]) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        // Find the nearest day at or before today with a season-level entry
        let seasons = ["Advent", "Christmas", "Ordinary Time", "Lent", "Easter"]
        for day in days.sorted(by: { $0.date < $1.date }).reversed() {
            if day.date <= today {
                for season in seasons where day.name.contains(season) {
                    return season
                }
            }
        }
        return "Ordinary Time"
    }

    // MARK: - Network
    // litcal API: https://litcal.johnromanodorazio.com/api/v3/LitCal?year=YYYY&Locale=EN

    private func fetchFromNetwork(year: Int) async throws -> [LiturgicalDay] {
        guard let url = URL(string: "https://litcal.johnromanodorazio.com/api/v3/LitCal?year=\(year)&Locale=EN") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try parseLitCal(data: data)
    }

    // MARK: - litcal JSON Parsing
    // Response: { "LitCal": { "EVENT_KEY": { "name", "color", "grade", "date" (unix timestamp) } } }

    private func parseLitCal(data: Data) throws -> [LiturgicalDay] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let litcal = root["LitCal"] as? [String: [String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let today = Calendar.current.startOfDay(for: Date())
        let cutoff = Calendar.current.date(byAdding: .day, value: 60, to: today)!

        var days: [LiturgicalDay] = []

        for (_, event) in litcal {
            guard let timestamp = event["date"] as? TimeInterval,
                  let name = event["name"] as? String else { continue }

            let date = Date(timeIntervalSince1970: timestamp)
            let dayStart = Calendar.current.startOfDay(for: date)

            guard dayStart >= today && dayStart <= cutoff else { continue }

            let colorArray = event["color"] as? [String] ?? []
            let color = colorArray.first ?? "green"
            let grade = event["grade"] as? Int ?? 0

            // grade: 0=Commemoratio, 1=Feria, 2=Memorial, 3=OptionalMemorial, 4=Feast, 5=Feast of the Lord, 6=Solemnity
            let isSolemnity = grade >= 6
            let isFeast = grade >= 4

            days.append(LiturgicalDay(
                date: dayStart,
                name: name,
                liturgicalColor: color,
                isSolemnity: isSolemnity,
                isFeast: isFeast
            ))
        }

        return days.sorted { $0.date < $1.date }
    }

    // MARK: - Cache (24-hour expiry)

    private func cacheURL(key: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(key)
    }

    private func loadFromCache(key: String) -> [LiturgicalDay]? {
        let url = cacheURL(key: key)
        guard let data = try? Data(contentsOf: url),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < 86400 else { return nil }
        return try? JSONDecoder().decode([CodableLiturgicalDay].self, from: data)
            .map { $0.toLiturgicalDay() }
    }

    private func saveToCache(_ days: [LiturgicalDay], key: String) {
        let url = cacheURL(key: key)
        let codable = days.map { CodableLiturgicalDay(from: $0) }
        guard let data = try? JSONEncoder().encode(codable) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// Codable bridge for LiturgicalDay (which itself isn't Codable due to Date init)
private struct CodableLiturgicalDay: Codable {
    let id: UUID
    let dateInterval: TimeInterval
    let name: String
    let liturgicalColor: String
    let isSolemnity: Bool
    let isFeast: Bool

    init(from day: LiturgicalDay) {
        self.id = day.id
        self.dateInterval = day.date.timeIntervalSince1970
        self.name = day.name
        self.liturgicalColor = day.liturgicalColor
        self.isSolemnity = day.isSolemnity
        self.isFeast = day.isFeast
    }

    func toLiturgicalDay() -> LiturgicalDay {
        LiturgicalDay(
            id: id,
            date: Date(timeIntervalSince1970: dateInterval),
            name: name,
            liturgicalColor: liturgicalColor,
            isSolemnity: isSolemnity,
            isFeast: isFeast
        )
    }
}
