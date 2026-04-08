import Foundation

final class ReadingsService {

    static let shared = ReadingsService()
    private init() {}

    private let baseURL = "https://api.aelf.org/v1/messes"

    // MARK: - Public API

    func fetchReadings(for date: Date) async throws -> DailyReadings {
        let key = cacheKey(for: date)
        if let cached = loadFromCache(key: key) { return cached }

        let readings = try await fetchFromNetwork(date: date)
        saveToCache(readings, key: key)
        return readings
    }

    // MARK: - Network

    private func fetchFromNetwork(date: Date) async throws -> DailyReadings {
        let dateString = isoDateString(date)
        guard let url = URL(string: "\(baseURL)/\(dateString)/en") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try parseAELF(data: data, dateString: dateString)
    }

    // MARK: - AELF JSON Parsing
    // Response: { "messes": [{ "lectures": [{ "type", "titre", "ref", "contenu" }] }] }

    private func parseAELF(data: Data, dateString: String) throws -> DailyReadings {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messes = root["messes"] as? [[String: Any]],
              let firstMesse = messes.first,
              let lectures = firstMesse["lectures"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let readings: [Reading] = lectures.compactMap { lecture in
            guard let type = lecture["type"] as? String,
                  let titre = lecture["titre"] as? String,
                  let ref = lecture["ref"] as? String,
                  let contenu = lecture["contenu"] as? String else { return nil }

            let title = localizedTitle(for: type)
            let cleanText = stripHTML(contenu)
            return Reading(type: type, title: title.isEmpty ? titre : title,
                           reference: ref, text: cleanText)
        }

        return DailyReadings(date: dateString, readings: readings)
    }

    private func localizedTitle(for type: String) -> String {
        switch type {
        case "lecture1":  return "First Reading"
        case "psaume":    return "Responsorial Psalm"
        case "lecture2":  return "Second Reading"
        case "evangile":  return "Gospel"
        default:          return ""
        }
    }

    private func stripHTML(_ html: String) -> String {
        // Remove common HTML tags while preserving paragraph breaks
        var result = html
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: "\n\n")
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    // MARK: - Cache

    private func cacheKey(for date: Date) -> String {
        "readings-\(isoDateString(date)).json"
    }

    private func cacheURL(key: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(key)
    }

    private func loadFromCache(key: String) -> DailyReadings? {
        let url = cacheURL(key: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DailyReadings.self, from: data)
    }

    private func saveToCache(_ readings: DailyReadings, key: String) {
        let url = cacheURL(key: key)
        guard let data = try? JSONEncoder().encode(readings) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func isoDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }
}
