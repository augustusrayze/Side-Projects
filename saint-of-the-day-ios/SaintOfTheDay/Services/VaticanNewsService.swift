import Foundation

struct VaticanNewsService {
    func fetchSaint(for date: Date) async throws -> (name: String, shortBio: String) {
        let url = buildURL(for: date)
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw VaticanNewsError.badResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw VaticanNewsError.parseFailure
        }

        let name = extractSaintName(from: html)
        let bio = extractShortBio(from: html)

        guard !name.isEmpty else { throw VaticanNewsError.parseFailure }
        return (name, bio)
    }

    // MARK: - Private

    private func buildURL(for date: Date) -> URL {
        let calendar = Calendar.current
        let month = String(format: "%02d", calendar.component(.month, from: date))
        let day = String(format: "%02d", calendar.component(.day, from: date))
        return URL(string: "https://www.vaticannews.va/en/saints/\(month)/\(day).html")!
    }

    private func extractSaintName(from html: String) -> String {
        // Try <h1 class="...">NAME</h1> pattern first
        if let name = extractBetweenTags(html: html, openPattern: "<h1", closeTag: "</h1>") {
            let clean = stripTags(name).trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        // Fallback: <title>NAME - Vatican News</title>
        if let title = extractBetweenTags(html: html, openPattern: "<title", closeTag: "</title>") {
            let clean = stripTags(title)
                .components(separatedBy: " - ").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !clean.isEmpty { return clean }
        }
        return ""
    }

    private func extractShortBio(from html: String) -> String {
        // Look for the first substantial paragraph inside the main content area
        var searchHtml = html
        if let contentRange = html.range(of: "content__text") {
            searchHtml = String(html[contentRange.upperBound...])
        }
        if let para = extractBetweenTags(html: searchHtml, openPattern: "<p", closeTag: "</p>") {
            let clean = stripTags(para).trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.count > 20 { return clean }
        }
        return ""
    }

    private func extractBetweenTags(html: String, openPattern: String, closeTag: String) -> String? {
        guard let openRange = html.range(of: openPattern, options: .caseInsensitive) else { return nil }
        let afterOpen = html[openRange.lowerBound...]
        guard let gtRange = afterOpen.range(of: ">") else { return nil }
        let afterGt = afterOpen[gtRange.upperBound...]
        guard let closeRange = afterGt.range(of: closeTag, options: .caseInsensitive) else { return nil }
        return String(afterGt[..<closeRange.lowerBound])
    }

    private func stripTags(_ input: String) -> String {
        var result = input
        while let openAngle = result.range(of: "<"),
              let closeAngle = result.range(of: ">", range: openAngle.lowerBound..<result.endIndex) {
            result.removeSubrange(openAngle.lowerBound...closeAngle.lowerBound)
        }
        return result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}

enum VaticanNewsError: Error, LocalizedError {
    case badResponse
    case parseFailure

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Vatican News returned an unexpected response."
        case .parseFailure: return "Could not parse the saint name from Vatican News."
        }
    }
}
