import Foundation

struct CatholicSaintContent {
    let canonicalName: String
    let shortBio: String
    let timePeriod: String?
    let sections: [SaintSection]
    let sourceURL: URL
}

struct CatholicEncyclopediaService {
    private let baseURL = URL(string: "https://www.newadvent.org")!
    private let encyclopediaBaseURL = URL(string: "https://www.newadvent.org/cathen/")!

    func fetchSaint(named name: String) async throws -> CatholicSaintContent? {
        guard let articleURL = try await resolveArticleURL(for: name) else {
            return nil
        }

        let html = try await fetchHTML(from: articleURL)
        let content = parseArticle(html: html, sourceURL: articleURL)
        guard !content.shortBio.isEmpty else {
            return nil
        }
        return content
    }

    private func resolveArticleURL(for name: String) async throws -> URL? {
        let candidates = titleCandidates(for: name)
        guard let firstLetter = firstIndexLetter(from: candidates) else {
            return nil
        }

        let indexURL = encyclopediaBaseURL.appending(path: "\(firstLetter).htm")
        let html = try await fetchHTML(from: indexURL)
        let links = parseIndexLinks(from: html)

        guard let bestLink = bestMatch(in: links, candidates: candidates) else {
            return nil
        }

        return URL(string: bestLink.href, relativeTo: encyclopediaBaseURL)?.absoluteURL
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return html
    }

    private func parseIndexLinks(from html: String) -> [(title: String, href: String)] {
        let pattern = #"<a\s+href="([^"]+\.htm)">([^<]+)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: range).compactMap { match in
            guard match.numberOfRanges == 3,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            let href = String(html[hrefRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = decodeHTMLEntities(String(html[titleRange]))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !href.isEmpty,
                  !title.isEmpty,
                  title.count > 2,
                  title.rangeOfCharacter(from: .letters) != nil,
                  !href.localizedCaseInsensitiveContains("/cathen/\(title.lowercased()).htm") else {
                return nil
            }
            return (title, href)
        }
    }

    private func bestMatch(in links: [(title: String, href: String)], candidates: [String]) -> (title: String, href: String)? {
        let normalizedCandidates = candidates.map(normalize)
        let candidateTokens = normalizedCandidates.map(significantTokens)
        let leadTokens = Set(candidateTokens.compactMap { $0.first })

        let scored = links.compactMap { link -> (score: Int, link: (title: String, href: String))? in
            let normalizedTitle = normalize(link.title)
            let titleTokens = significantTokens(normalizedTitle)
            guard !titleTokens.isEmpty else { return nil }

            var score = 0
            for (index, candidate) in normalizedCandidates.enumerated() {
                let overlap = Set(titleTokens).intersection(candidateTokens[index]).count
                if normalizedTitle == candidate {
                    score = max(score, 100)
                } else if normalizedTitle.contains(candidate) || candidate.contains(normalizedTitle) {
                    score = max(score, 75)
                } else if overlap >= 2 {
                    score = max(score, overlap * 18)
                } else if overlap == 1,
                          let candidateLead = candidateTokens[index].first,
                          titleTokens.first == candidateLead,
                          candidateTokens[index].count == 1 || titleTokens.count == 1 {
                    score = max(score, 32)
                }
            }

            if let firstTitleToken = titleTokens.first, leadTokens.contains(firstTitleToken) {
                score += 8
            }

            return score >= 32 ? (score, link) : nil
        }

        return scored.max(by: { lhs, rhs in lhs.score < rhs.score })?.link
    }

    private func parseArticle(html: String, sourceURL: URL) -> CatholicSaintContent {
        let text = cleanedArticleText(from: html)
        let blocks = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var title = ""
        var introParagraphs: [String] = []
        var currentHeading: String?
        var groupedSections: [(heading: String, body: String)] = []
        var currentParagraphs: [String] = []

        func flushCurrentSection() {
            guard let currentHeading, !currentParagraphs.isEmpty else { return }
            groupedSections.append((heading: currentHeading, body: currentParagraphs.joined(separator: "\n\n")))
            currentParagraphs.removeAll()
        }

        for block in blocks {
            if block.hasPrefix("# ") {
                title = String(block.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if block.hasPrefix("## ") {
                let heading = String(block.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                if heading.caseInsensitiveCompare("Sources") == .orderedSame || heading.caseInsensitiveCompare("About this page") == .orderedSame {
                    flushCurrentSection()
                    break
                }
                flushCurrentSection()
                currentHeading = heading
                continue
            }

            if block.localizedCaseInsensitiveContains("Please help support the mission of New Advent") {
                continue
            }

            if currentHeading == nil {
                introParagraphs.append(block)
            } else {
                currentParagraphs.append(block)
            }
        }
        flushCurrentSection()

        let sections = buildSections(introParagraphs: introParagraphs, groupedSections: groupedSections)
        let shortBioSource = sections.first(where: { $0.kind == .biography })?.body ?? introParagraphs.joined(separator: " ")
        let shortBio = extractShortBio(from: shortBioSource)
        let canonicalName = title.isEmpty ? inferFallbackTitle(from: sections) : title
        let timePeriod = extractTimePeriod(from: shortBioSource)

        return CatholicSaintContent(
            canonicalName: canonicalName,
            shortBio: shortBio,
            timePeriod: timePeriod,
            sections: sections,
            sourceURL: sourceURL
        )
    }

    private func buildSections(introParagraphs: [String], groupedSections: [(heading: String, body: String)]) -> [SaintSection] {
        var biographyBodies = introParagraphs
        var writingsBodies: [String] = []
        var miraclesBodies: [String] = []
        var patronageBodies: [String] = []

        for section in groupedSections {
            let kind = kindForHeading(section.heading)
            switch kind {
            case .writings:
                writingsBodies.append(section.body)
            case .miracles:
                miraclesBodies.append(section.body)
            case .patronages:
                patronageBodies.append(section.body)
            default:
                biographyBodies.append(section.body)
            }
        }

        if patronageBodies.isEmpty {
            let combinedBody = (introParagraphs + groupedSections.map(\.body)).joined(separator: " ")
            let patronageSentences = splitIntoSentences(combinedBody).filter { $0.localizedCaseInsensitiveContains("patron of") }
            if !patronageSentences.isEmpty {
                patronageBodies = patronageSentences
            }
        }

        var sections: [SaintSection] = []

        let biography = biographyBodies.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !biography.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: biography))
        }

        let patronages = patronageBodies.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !patronages.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .patronages, heading: "Patronages", body: patronages))
        }

        let miracles = miraclesBodies.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !miracles.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .miracles, heading: "Miracles", body: miracles))
        }

        let writings = writingsBodies.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !writings.isEmpty {
            sections.append(SaintSection(id: UUID(), kind: .writings, heading: "Writings", body: writings))
        }

        return sections
    }

    private func cleanedArticleText(from html: String) -> String {
        var result = html
        result = replacing(result, pattern: #"(?is)<script[^>]*>.*?</script>"#, with: "")
        result = replacing(result, pattern: #"(?is)<style[^>]*>.*?</style>"#, with: "")
        result = replacing(result, pattern: #"(?is)<h1[^>]*>(.*?)</h1>"#, with: "\n# $1\n")
        result = replacing(result, pattern: #"(?is)<h2[^>]*>(.*?)</h2>"#, with: "\n## $1\n")
        result = replacing(result, pattern: #"(?is)<p[^>]*>"#, with: "")
        result = replacing(result, pattern: #"(?i)</p>"#, with: "\n\n")
        result = replacing(result, pattern: #"(?i)<br\s*/?>"#, with: "\n")
        result = replacing(result, pattern: #"(?is)<[^>]+>"#, with: "")
        result = decodeHTMLEntities(result)
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replacing(_ text: String, pattern: String, with template: String) -> String {
        text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }

    private func titleCandidates(for name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let simplified = simplifyName(trimmed)
        let base = simplified
            .replacingOccurrences(of: "St.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Saint", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var candidates = [trimmed, simplified, base]
        if !base.isEmpty {
            candidates.append("Saint \(base)")
            candidates.append("St. \(base)")
        }

        if let firstComponent = base.split(separator: ",").first {
            let segment = firstComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty {
                candidates.append(segment)
                candidates.append("\(segment), Saint")
            }
        }

        let tokens = significantTokens(normalize(base))
        if tokens.count == 1, let firstWord = tokens.first {
            candidates.append(firstWord.capitalized)
            candidates.append("\(firstWord.capitalized), Saint")
        }

        return Array(NSOrderedSet(array: candidates.filter { !$0.isEmpty })) as? [String] ?? candidates
    }

    private func simplifyName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "St.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Saint", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 2,
           let title = parts.dropFirst().first(where: { $0.localizedCaseInsensitiveContains("Bishop of ") }),
           let range = title.range(of: "Bishop of ", options: .caseInsensitive) {
            var location = title[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let andRange = location.range(of: " and ", options: .caseInsensitive) {
                location = location[..<andRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !location.isEmpty {
                return "\(parts[0]) of \(location)"
            }
        }

        return parts.first ?? cleaned
    }

    private func firstIndexLetter(from candidates: [String]) -> String? {
        for candidate in candidates {
            if let token = significantTokens(normalize(candidate)).first,
               let letter = token.first(where: { $0.isLetter }) {
                return String(letter).lowercased()
            }
        }
        return nil
    }

    private func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "st.", with: "saint")
            .replacingOccurrences(of: "st ", with: "saint ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func significantTokens(_ value: String) -> [String] {
        let stopWords: Set<String> = ["saint", "st", "of", "the", "de", "la", "le", "and", "blessed", "doctor", "church", "bishop"]
        return value.split(separator: " ").map(String.init).filter { !stopWords.contains($0) }
    }

    private func kindForHeading(_ heading: String) -> SectionKind {
        let lower = heading.lowercased()
        if lower.contains("writing") || lower.contains("work") || lower.contains("doctrine") || lower.contains("legacy") {
            return .writings
        }
        if lower.contains("miracle") {
            return .miracles
        }
        if lower.contains("patron") {
            return .patronages
        }
        return .biography
    }

    private func extractShortBio(from text: String) -> String {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = paragraphs.first else {
            return ""
        }

        let pieces = first.components(separatedBy: ". ")
        let joined = pieces.prefix(3).joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { return first }
        return joined.hasSuffix(".") ? joined : joined + "."
    }

    private func extractTimePeriod(from text: String) -> String? {
        let patterns = [
            #"\(c\.\s*\d{3,4}\s*[–\-]\s*\d{3,4}"#,
            #"\(\d{3,4}\s*[–\-]\s*\d{3,4}"#,
            #"born\s+about\s+\d{3,4}"#,
            #"died\s+probably\s+\d{3,4}"#
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func inferFallbackTitle(from sections: [SaintSection]) -> String {
        sections.first?.body.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Saint"
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
            .replacingOccurrences(of: "&mdash;", with: "-")
            .replacingOccurrences(of: "&ndash;", with: "-")
    }
}
