import Foundation

final class ReadingsService {

    static let shared = ReadingsService()
    private init() {}

    private let baseURL = URL(string: "https://bible.usccb.org")!

    // MARK: - Public API

    func fetchReadings(for date: Date) async throws -> DailyReadings {
        let key = cacheKey(for: date)
        if let cached = loadFromCache(key: key), !cached.readings.isEmpty {
            return cached
        }

        let readings = try await fetchFromNetwork(date: date)
        saveToCache(readings, key: key)
        return readings
    }

    // MARK: - Network

    private func fetchFromNetwork(date: Date) async throws -> DailyReadings {
        let dateString = isoDateString(date)
        let url = baseURL.appending(path: "bible/readings/\(usccbDatePath(for: date)).cfm")

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let readings = parseUSCCB(html: html)
        guard !readings.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        return DailyReadings(date: dateString, readings: readings)
    }

    // MARK: - USCCB HTML Parsing

    private func parseUSCCB(html: String) -> [Reading] {
        html.components(separatedBy: #"<div class="innerblock">"#).compactMap { block in
            guard block.contains(#"<div class="content-header">"#),
                  block.contains(#"<div class="content-body">"#),
                  let titleHTML = extractBetween(block, openPattern: #"<h3 class="name">"#, closePattern: "</h3>"),
                  let bodyHTML = extractBetween(block, openPattern: #"<div class="content-body">"#, closePattern: "</div>") else {
                return nil
            }

            let referenceHTML = extractBetween(block, openPattern: "<a", closePattern: "</a>")
            let reference = referenceHTML.flatMap { html in
                extractAfterFirstTagClose(html).map(cleanText)
            } ?? ""
            let title = cleanText(titleHTML)
            let body = cleanText(bodyHTML)
            guard !title.isEmpty, !body.isEmpty else { return nil }

            return Reading(
                type: readingType(for: title),
                title: title,
                reference: reference,
                text: body
            )
        }
    }

    private func extractBetween(_ text: String, openPattern: String, closePattern: String) -> String? {
        guard let openRange = text.range(of: openPattern, options: .caseInsensitive) else { return nil }
        let afterOpen = text[openRange.upperBound...]
        guard let closeRange = afterOpen.range(of: closePattern, options: .caseInsensitive) else { return nil }
        return String(afterOpen[..<closeRange.lowerBound])
    }

    private func extractAfterFirstTagClose(_ text: String) -> String? {
        guard let closeRange = text.range(of: ">") else { return nil }
        return String(text[closeRange.upperBound...])
    }

    private func readingType(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("psalm") { return "psaume" }
        if lower.contains("gospel") { return "evangile" }
        if lower.contains("reading 2") { return "lecture2" }
        if lower.contains("alleluia") { return "alleluia" }
        if lower.contains("sequence") { return "sequence" }
        return "lecture1"
    }

    private func cleanText(_ html: String) -> String {
        var result = html
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = decodeHTMLEntities(result)
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
    }

    // MARK: - Cache

    private func cacheKey(for date: Date) -> String {
        "readings-v2-\(isoDateString(date)).json"
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

    private func usccbDatePath(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMddyy"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }
}
