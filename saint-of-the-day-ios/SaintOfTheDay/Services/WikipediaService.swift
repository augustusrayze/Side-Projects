import Foundation

struct WikipediaService {
    // MARK: - Public

    func fetchSaint(named name: String, for date: Date = Date()) async throws -> Saint {
        let title = try await resolveTitle(for: name)
        return try await fetchArticle(title: title, originalName: name, date: date)
    }

    // MARK: - Title Resolution

    private func resolveTitle(for name: String) async throws -> String {
        // First attempt: direct lookup
        if let page = try? await queryPages(title: name),
           page.missing != true,
           let extract = page.extract,
           !extract.isEmpty,
           !isDisambiguation(extract) {
            return page.title
        }
        // Fallback: search with a Catholic qualifier and a simplified saint title.
        return try await searchTitle(for: "\(searchQueryName(for: name)) Catholic saint")
    }

    private func searchQueryName(for name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "St.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Saint", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 2,
           let title = parts.dropFirst().first(where: { $0.localizedCaseInsensitiveContains("Bishop of ") }),
           let locationRange = title.range(of: "Bishop of ", options: .caseInsensitive) {
            let location = title[locationRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !location.isEmpty {
                return "\(parts[0]) of \(location)"
            }
        }

        return cleaned
    }

    private func searchTitle(for query: String) async throws -> String {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "list", value: "search"),
            .init(name: "srsearch", value: query),
            .init(name: "srlimit", value: "5"),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(WikipediaSearchResponse.self, from: data)
        guard let first = response.query.search.first else {
            throw WikipediaError.notFound
        }
        return first.title
    }

    // MARK: - Article Fetch

    private func fetchArticle(title: String, originalName: String, date: Date) async throws -> Saint {
        guard let page = try await queryPages(title: title) else {
            throw WikipediaError.notFound
        }

        let extract = page.extract ?? ""
        let sections = parseSections(from: extract)
        let shortBio = extractShortBio(from: extract)
        let timePeriod = extractTimePeriod(from: extract)
        let imageURL = page.thumbnail.flatMap { URL(string: $0.source) }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"

        return Saint(
            canonicalName: page.title,
            feastDay: dateFormatter.string(from: date),
            feastMonth: components.month ?? 1,
            feastDayOfMonth: components.day ?? 1,
            timePeriod: timePeriod,
            shortBio: shortBio,
            popularQuote: nil,
            imageURL: imageURL,
            wikipediaTitle: page.title,
            sections: sections,
            fetchedDate: date
        )
    }

    private func queryPages(title: String) async throws -> WikipediaPage? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "titles", value: title),
            .init(name: "prop", value: "extracts|pageimages"),
            .init(name: "exintro", value: "false"),
            .init(name: "explaintext", value: "true"),
            .init(name: "exsectionformat", value: "plain"),
            .init(name: "pithumbsize", value: "600"),
            .init(name: "redirects", value: "1"),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(WikipediaQueryResponse.self, from: data)
        return response.query.pages.first
    }

    // MARK: - Parsing

    private func isDisambiguation(_ extract: String) -> Bool {
        extract.lowercased().contains("may refer to") || extract.lowercased().contains("disambiguation")
    }

    private func extractShortBio(from extract: String) -> String {
        let paragraphs = extract
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isSectionHeading($0) }
        guard let first = paragraphs.first else { return "" }
        // Return first 2 sentences
        let sentences = first.components(separatedBy: ". ")
        return sentences.prefix(3).joined(separator: ". ") + (sentences.count > 3 ? "." : "")
    }

    private func extractTimePeriod(from extract: String) -> String? {
        let patterns = [
            #"\(c\.\s*\d{3,4}\s*[–\-]\s*\d{3,4}"#,
            #"\(\d{3,4}\s*[–\-]\s*\d{3,4}"#,
            #"born\s+c?\.\s*\d{3,4}"#,
        ]
        for pattern in patterns {
            if let range = extract.range(of: pattern, options: .regularExpression) {
                var result = String(extract[range])
                    .replacingOccurrences(of: "(", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !result.hasSuffix(")") { result += ")" }
                result = "(" + result
                return result
            }
        }
        return nil
    }

    private func parseSections(from extract: String) -> [SaintSection] {
        let paragraphs = extract
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var sections: [SaintSection] = []
        var currentHeading = "Biography"
        var currentKind: SectionKind = .biography
        var currentBody: [String] = []

        for paragraph in paragraphs {
            if isSectionHeading(paragraph) {
                // Flush previous section
                if !currentBody.isEmpty {
                    sections.append(SaintSection(
                        id: UUID(),
                        kind: currentKind,
                        heading: currentHeading,
                        body: currentBody.joined(separator: "\n\n")
                    ))
                    currentBody = []
                }
                currentHeading = paragraph
                currentKind = kindForHeading(paragraph)
            } else {
                currentBody.append(paragraph)
            }
        }

        // Flush last section
        if !currentBody.isEmpty {
            sections.append(SaintSection(
                id: UUID(),
                kind: currentKind,
                heading: currentHeading,
                body: currentBody.joined(separator: "\n\n")
            ))
        }

        return sections.isEmpty ? fallbackSection(from: extract) : sections
    }

    private func isSectionHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count < 60
            && !trimmed.hasSuffix(".")
            && !trimmed.hasSuffix(",")
            && trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
            && !trimmed.contains("\n")
    }

    private func kindForHeading(_ heading: String) -> SectionKind {
        let lower = heading.lowercased()
        let map: [(keywords: [String], kind: SectionKind)] = [
            (["early life", "life", "biography", "background", "birth", "childhood"], .biography),
            (["miracle", "veneration", "cult", "intercession", "healing"], .miracles),
            (["writing", "work", "book", "letter", "treatise", "legacy", "thought"], .writings),
            (["patron", "patronage", "intercede"], .patronages),
            (["canoniz", "beatif", "saint"], .canonization),
        ]
        for entry in map {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return entry.kind
            }
        }
        return .other
    }

    private func fallbackSection(from extract: String) -> [SaintSection] {
        guard !extract.isEmpty else { return [] }
        return [SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: extract)]
    }
}

// MARK: - Codable Response Models

private struct WikipediaQueryResponse: Decodable {
    let query: WikipediaQuery
}

private struct WikipediaQuery: Decodable {
    let pages: [WikipediaPage]
}

struct WikipediaPage: Decodable {
    let title: String
    let extract: String?
    let thumbnail: WikipediaThumbnail?
    let missing: Bool?
}

struct WikipediaThumbnail: Decodable {
    let source: String
}

private struct WikipediaSearchResponse: Decodable {
    let query: WikipediaSearchQuery
}

private struct WikipediaSearchQuery: Decodable {
    let search: [WikipediaSearchResult]
}

private struct WikipediaSearchResult: Decodable {
    let title: String
}

enum WikipediaError: Error, LocalizedError {
    case notFound

    var errorDescription: String? {
        "Could not find a Wikipedia article for this saint."
    }
}
