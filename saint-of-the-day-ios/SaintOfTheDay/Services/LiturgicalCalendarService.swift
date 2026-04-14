import Foundation

final class LiturgicalCalendarService {

    static let shared = LiturgicalCalendarService()
    private init() {}

    private let baseURL = URL(string: "https://bible.usccb.org")!

    // MARK: - Public API

    func fetchCalendar(for year: Int) async throws -> [LiturgicalDay] {
        let key = "litcal-v2-\(year).json"
        if let cached = loadFromCache(key: key), !cached.isEmpty {
            return cached
        }

        let days = try await fetchFromNetwork(year: year)
        saveToCache(days, key: key)
        return days
    }

    func currentSeason(from days: [LiturgicalDay]) -> String {
        let today = Calendar.current.startOfDay(for: Date())
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

    private func fetchFromNetwork(year: Int) async throws -> [LiturgicalDay] {
        var days: [LiturgicalDay] = []
        var seenKeys: Set<String> = []

        // USCCB returns 10 upcoming readings per page. Six pages gives the app's 60-day calendar window.
        for page in 0..<6 {
            let pageDays = try await fetchListingPage(page: page)
            for day in pageDays where Calendar.current.component(.year, from: day.date) == year {
                let key = "\(day.date.timeIntervalSince1970)-\(day.name)"
                if seenKeys.insert(key).inserted {
                    days.append(day)
                }
            }
        }

        let today = Calendar.current.startOfDay(for: Date())
        let cutoff = Calendar.current.date(byAdding: .day, value: 60, to: today)!
        let filtered = days
            .filter { $0.date >= today && $0.date <= cutoff }
            .sorted { $0.date < $1.date }

        guard !filtered.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        return filtered
    }

    private func fetchListingPage(page: Int) async throws -> [LiturgicalDay] {
        var components = URLComponents(url: baseURL.appending(path: "readings"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "_wrapper_format", value: "html"),
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        return parseUSCCBListing(html: html)
    }

    // MARK: - USCCB HTML Parsing

    private func parseUSCCBListing(html: String) -> [LiturgicalDay] {
        let pattern = #"<li\s+class="teaser">.*?<a\s+href="([^"]+)"\s+data-colors="([^"]*)">.*?<span[^>]*>(.*?)</span>.*?</a>\s*</li>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard match.numberOfRanges >= 4,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let colorRange = Range(match.range(at: 2), in: html),
                  let nameRange = Range(match.range(at: 3), in: html),
                  let date = dateFromUSCCBPath(String(html[hrefRange])) else {
                return nil
            }

            let name = cleanText(String(html[nameRange]))
            guard !name.isEmpty else { return nil }

            let color = normalizedColor(String(html[colorRange]))
            return LiturgicalDay(
                date: Calendar.current.startOfDay(for: date),
                name: name,
                liturgicalColor: color,
                isSolemnity: isSolemnity(name),
                isFeast: isFeast(name)
            )
        }
    }

    private func dateFromUSCCBPath(_ path: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"/(\d{2})(\d{2})(\d{2})\.cfm"#) else {
            return nil
        }

        let nsRange = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = regex.firstMatch(in: path, range: nsRange),
              match.numberOfRanges == 4,
              let monthRange = Range(match.range(at: 1), in: path),
              let dayRange = Range(match.range(at: 2), in: path),
              let yearRange = Range(match.range(at: 3), in: path),
              let month = Int(path[monthRange]),
              let day = Int(path[dayRange]),
              let twoDigitYear = Int(path[yearRange]) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2000 + twoDigitYear
        components.month = month
        components.day = day
        return components.date
    }

    private func normalizedColor(_ colors: String) -> String {
        let first = colors
            .split { $0 == "," || $0 == " " }
            .first
            .map(String.init) ?? "green"
        return first.lowercased()
    }

    private func isSolemnity(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("Solemnity")
    }

    private func isFeast(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("Feast")
            || name.localizedCaseInsensitiveContains("Solemnity")
            || name.localizedCaseInsensitiveContains("Sunday")
    }

    private func cleanText(_ html: String) -> String {
        decodeHTMLEntities(html)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
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
