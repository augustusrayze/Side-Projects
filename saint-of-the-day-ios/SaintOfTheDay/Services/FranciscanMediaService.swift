import Foundation

struct FranciscanSaintContent {
    let canonicalName: String
    let shortBio: String
    let timePeriod: String?
    let sections: [SaintSection]
    let sourceURL: URL
}

struct FranciscanMediaService {
    private let baseURL = URL(string: "https://www.franciscanmedia.org")!

    func fetchSaint(named name: String) async throws -> FranciscanSaintContent? {
        for candidate in searchCandidates(for: name) {
            let posts = try await searchPosts(query: candidate)
            if let post = bestMatch(in: posts, for: name) {
                return parse(post: post)
            }
        }
        return nil
    }

    private func searchPosts(query: String) async throws -> [FranciscanPost] {
        var components = URLComponents(url: baseURL.appending(path: "wp-json/wp/v2/posts"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "per_page", value: "5")
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([FranciscanPost].self, from: data)
    }

    private func bestMatch(in posts: [FranciscanPost], for name: String) -> FranciscanPost? {
        let candidates = searchCandidates(for: name).map(normalize)
        let candidateTokens = candidates.map(significantTokens)

        let scored = posts.compactMap { post -> (Int, FranciscanPost)? in
            let normalizedTitle = normalize(post.title.rendered)
            let titleTokens = significantTokens(normalizedTitle)
            guard !titleTokens.isEmpty else { return nil }

            var score = 0
            for (index, candidate) in candidates.enumerated() {
                if normalizedTitle == candidate {
                    score = max(score, 100)
                } else if normalizedTitle.contains(candidate) || candidate.contains(normalizedTitle) {
                    score = max(score, 80)
                } else {
                    let overlap = Set(titleTokens).intersection(candidateTokens[index]).count
                    score = max(score, overlap * 20)
                }
            }

            return score >= 40 ? (score, post) : nil
        }

        return scored.max(by: { $0.0 < $1.0 })?.1
    }

    private func parse(post: FranciscanPost) -> FranciscanSaintContent? {
        guard let sourceURL = URL(string: post.link) else { return nil }

        let title = cleanHTML(post.title.rendered)
        let shortBio = cleanHTML(post.excerpt.rendered)
        let content = parseSections(from: post.content.rendered, fallbackBio: shortBio)
        let timePeriod = extractTimePeriod(from: post.content.rendered)

        guard !title.isEmpty, !shortBio.isEmpty else {
            return nil
        }

        return FranciscanSaintContent(
            canonicalName: title,
            shortBio: shortBio,
            timePeriod: timePeriod,
            sections: content,
            sourceURL: sourceURL
        )
    }

    private func parseSections(from html: String, fallbackBio: String) -> [SaintSection] {
        let normalized = html
            .replacingOccurrences(of: #"(?is)<figure[^>]*>.*?</figure>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<audio[^>]*>.*?</audio>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<hr[^>]*>"#, with: "", options: .regularExpression)

        let tokens = normalized.components(separatedBy: #"(?i)(?=<h[1-6][^>]*>)"#)
        var biographyParts: [String] = []
        var miraclesParts: [String] = []
        var writingsParts: [String] = []
        var patronageParts: [String] = []

        for token in tokens {
            let heading = firstMatch(in: token, pattern: #"(?is)<h[1-6][^>]*>(.*?)</h[1-6]>"#).map(cleanHTML) ?? ""
            let paragraphs = matches(in: token, pattern: #"(?is)<p[^>]*>(.*?)</p>"#)
                .map(cleanHTML)
                .filter { !$0.isEmpty }

            if heading.isEmpty {
                biographyParts.append(contentsOf: paragraphs)
                continue
            }

            let body = paragraphs.joined(separator: "\n\n")
            guard !body.isEmpty else { continue }

            switch kindForHeading(heading) {
            case .miracles:
                miraclesParts.append(body)
            case .writings:
                writingsParts.append(body)
            case .patronages:
                patronageParts.append(body)
            default:
                biographyParts.append(body)
            }
        }

        if biographyParts.isEmpty {
            biographyParts = [fallbackBio]
        }

        if patronageParts.isEmpty {
            let combined = (biographyParts + miraclesParts + writingsParts).joined(separator: " ")
            let patronageSentences = splitIntoSentences(combined).filter { $0.localizedCaseInsensitiveContains("patron") }
            if !patronageSentences.isEmpty {
                patronageParts = patronageSentences
            }
        }

        var sections: [SaintSection] = []
        let bio = biographyParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !bio.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: bio))
        }

        let patronage = patronageParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !patronage.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .patronages, heading: "Patronages", body: patronage))
        }

        let miracles = miraclesParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !miracles.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .miracles, heading: "Miracles", body: miracles))
        }

        let writings = writingsParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !writings.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .writings, heading: "Writings", body: writings))
        }

        return sections
    }

    private func kindForHeading(_ heading: String) -> SectionKind {
        let lower = heading.lowercased()
        if lower.contains("patron") {
            return .patronages
        }
        if lower.contains("miracle") {
            return .miracles
        }
        if lower.contains("reflection") || lower.contains("writ") || lower.contains("homily") || lower.contains("letter") || lower.contains("work") {
            return .writings
        }
        return .biography
    }

    private func extractTimePeriod(from html: String) -> String? {
        let cleaned = cleanHTML(html)
        let patterns = [
            #"\(c\.\s*\d{3,4}\s*[–-]\s*[^)]+\)"#,
            #"\(\d{3,4}\s*[–-]\s*[^)]+\)"#
        ]
        for pattern in patterns {
            if let range = cleaned.range(of: pattern, options: .regularExpression) {
                return String(cleaned[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func searchCandidates(for name: String) -> [String] {
        let simplified = simplify(name)
        let withoutSaint = simplified
            .replacingOccurrences(of: "Saint ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "St. ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let values = [name, simplified, withoutSaint]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(NSOrderedSet(array: values)) as? [String] ?? values
    }

    private func simplify(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 2,
           let title = parts.dropFirst().first(where: { $0.localizedCaseInsensitiveContains("Bishop of ") }),
           let range = title.range(of: "Bishop of ", options: .caseInsensitive) {
            var location = title[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let andRange = location.range(of: " and ", options: .caseInsensitive) {
                location = location[..<andRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return "\(parts[0]) of \(location)"
        }
        return parts.first ?? cleaned
    }

    private func normalize(_ value: String) -> String {
        cleanHTML(value)
            .lowercased()
            .replacingOccurrences(of: "st.", with: "saint")
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func significantTokens(_ value: String) -> [String] {
        let stopWords: Set<String> = ["saint", "st", "of", "the", "and", "de", "la", "le", "bishop", "doctor", "church"]
        return value.split(separator: " ").map(String.init).filter { !stopWords.contains($0) }
    }

    private func cleanHTML(_ html: String) -> String {
        decodeHTMLEntities(
            html
                .replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[swiftRange])
        }
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let pattern = #"(?<=[.!?])\s+"#
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }

        var sentences: [String] = []
        var lastLocation = 0
        for match in regex.matches(in: text, options: [], range: range) {
            let sentenceRange = NSRange(location: lastLocation, length: match.range.location - lastLocation)
            if let swiftRange = Range(sentenceRange, in: text) {
                let sentence = text[swiftRange].trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
            }
            lastLocation = match.range.location + match.range.length
        }

        let tailRange = NSRange(location: lastLocation, length: range.length - lastLocation)
        if let swiftRange = Range(tailRange, in: text) {
            let sentence = text[swiftRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        return sentences
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
            .replacingOccurrences(of: "&#8217;", with: "'")
    }
}

private struct FranciscanPost: Decodable {
    struct RenderedText: Decodable {
        let rendered: String
    }

    let title: RenderedText
    let excerpt: RenderedText
    let content: RenderedText
    let link: String
}
