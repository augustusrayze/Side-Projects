import Foundation
import Observation

enum LoadState {
    case idle
    case loading
    case loaded(Saint)
    case failed(Error)
}

@Observable
final class SaintRepository {
    private(set) var state: LoadState = .idle
    let date: Date

    private let vaticanService = VaticanNewsService()
    private let catholicEncyclopediaService = CatholicEncyclopediaService()
    private let franciscanMediaService = FranciscanMediaService()
    private let wikipediaService = WikipediaService()
    private let cacheService = CacheService()
    private let quoteService = SaintQuoteService.shared
    private let profileService = SaintProfileService.shared
    private let cardFallbackService = SaintCardFallbackService.shared

    init(date: Date = Date()) {
        self.date = date
    }

    func fetchIfNeeded() async {
        if case .idle = state {
            await fetchSaint(for: date)
        }
    }

    func fetchSaint(for date: Date, ignoringCache: Bool = false) async {
        if !ignoringCache, let cached = try? cacheService.load(for: date), isUsable(cached) {
            let completedCached = saintEnsuringRequiredCards(cached, originalName: cached.canonicalName, fallbackBio: cached.shortBio, date: date)
            if completionScore(for: completedCached) > completionScore(for: cached) {
                try? cacheService.save(completedCached, for: date)
            }
            state = .loaded(completedCached)
            return
        }

        state = .loading

        do {
            let (name, vaticanBio) = try await vaticanService.fetchSaint(for: date)
            let catholicSource = try? await catholicEncyclopediaService.fetchSaint(named: name)
            let franciscanSource = try? await franciscanMediaService.fetchSaint(named: name)
            let wikipediaSaint = try? await wikipediaService.fetchSaint(named: name, for: date)
            let profileNames = [name, catholicSource?.canonicalName, franciscanSource?.canonicalName, wikipediaSaint?.canonicalName, wikipediaSaint?.wikipediaTitle]
                .compactMap { $0 }
            let profile = profileService.profile(forNames: profileNames)

            let resolvedSaint = mergedSaint(
                profile: profile,
                catholicSource: catholicSource,
                franciscanSource: franciscanSource,
                wikipediaSaint: wikipediaSaint,
                originalName: name,
                vaticanBio: vaticanBio,
                date: date
            )

            let matchedFallback = cardFallbackService.record(forNames: profileNames + [resolvedSaint.canonicalName, resolvedSaint.wikipediaTitle])
            let verifiedSaint = verifiedMatch(for: name, candidate: resolvedSaint, fallbackBio: vaticanBio, date: date)
            let canonicalSaint = saintWithCanonicalIdentity(
                verifiedSaint,
                originalName: name,
                profile: profile,
                fallbackRecord: matchedFallback
            )
            let quotedSaint = saintWithQuote(canonicalSaint, originalName: name)
            let polishedSaint = polishedSaint(quotedSaint)
            let completedSaint = saintEnsuringRequiredCards(polishedSaint, originalName: name, fallbackBio: vaticanBio, date: date)
            try? cacheService.save(completedSaint, for: date)
            state = .loaded(completedSaint)

            if Calendar.current.isDateInToday(date), let imageURL = completedSaint.imageURL {
                Task {
                    await NotificationService.shared.updateNotificationImage(
                        from: imageURL,
                        saintName: completedSaint.canonicalName,
                        date: date
                    )
                }
            }
        } catch {
            if let stale = try? cacheService.load(for: date), isUsable(stale) {
                let completedStale = saintEnsuringRequiredCards(stale, originalName: stale.canonicalName, fallbackBio: stale.shortBio, date: date)
                if completionScore(for: completedStale) > completionScore(for: stale) {
                    try? cacheService.save(completedStale, for: date)
                }
                state = .loaded(completedStale)
            } else {
                state = .failed(error)
            }
        }
    }

    func refresh() async {
        state = .idle
        await fetchSaint(for: date, ignoringCache: true)
    }

    private func isUsable(_ saint: Saint) -> Bool {
        !saint.shortBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && saint.canonicalName.localizedCaseInsensitiveCompare("Saint of the day") != .orderedSame
    }

    private func mergedSaint(
        profile: SaintProfileRecord?,
        catholicSource: CatholicSaintContent?,
        franciscanSource: FranciscanSaintContent?,
        wikipediaSaint: Saint?,
        originalName: String,
        vaticanBio: String,
        date: Date
    ) -> Saint {
        let profileSections = profile?.sections.map {
            SaintSection(id: UUID(), kind: $0.kind, heading: $0.heading, body: $0.body)
        } ?? []

        if let catholicSource {
            let fallbackSections = (franciscanSource?.sections ?? []) + (wikipediaSaint?.sections ?? [])
            let mergedSections = applyingProfileOverrides(
                profileSections,
                to: mergedSections(primary: catholicSource.sections, fallback: fallbackSections)
            )

            return Saint(
                canonicalName: profile?.canonicalName ?? resolvedName(primary: catholicSource.canonicalName, secondary: franciscanSource?.canonicalName, tertiary: wikipediaSaint?.canonicalName, fallback: originalName),
                feastDay: wikipediaSaint?.feastDay ?? feastDayString(for: date),
                feastMonth: wikipediaSaint?.feastMonth ?? Calendar.current.component(.month, from: date),
                feastDayOfMonth: wikipediaSaint?.feastDayOfMonth ?? Calendar.current.component(.day, from: date),
                timePeriod: firstNonEmpty(profile?.timePeriod, catholicSource.timePeriod, franciscanSource?.timePeriod, wikipediaSaint?.timePeriod),
                shortBio: bestShortBio(primary: profile?.shortBio, secondary: catholicSource.shortBio, tertiary: franciscanSource?.shortBio, quaternary: wikipediaSaint?.shortBio, fallback: vaticanBio),
                popularQuote: nil,
                imageURL: wikipediaSaint?.imageURL,
                wikipediaTitle: wikipediaSaint?.wikipediaTitle ?? catholicSource.canonicalName,
                sections: mergedSections.isEmpty ? [SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: bestShortBio(primary: profile?.shortBio, secondary: catholicSource.shortBio, tertiary: franciscanSource?.shortBio, quaternary: wikipediaSaint?.shortBio, fallback: vaticanBio))] : mergedSections,
                fetchedDate: date
            )
        }

        if let franciscanSource {
            let mergedSections = applyingProfileOverrides(
                profileSections,
                to: mergedSections(primary: franciscanSource.sections, fallback: wikipediaSaint?.sections ?? [])
            )

            return Saint(
                canonicalName: profile?.canonicalName ?? franciscanSource.canonicalName,
                feastDay: wikipediaSaint?.feastDay ?? feastDayString(for: date),
                feastMonth: wikipediaSaint?.feastMonth ?? Calendar.current.component(.month, from: date),
                feastDayOfMonth: wikipediaSaint?.feastDayOfMonth ?? Calendar.current.component(.day, from: date),
                timePeriod: firstNonEmpty(profile?.timePeriod, franciscanSource.timePeriod, wikipediaSaint?.timePeriod),
                shortBio: bestShortBio(primary: profile?.shortBio, secondary: franciscanSource.shortBio, tertiary: wikipediaSaint?.shortBio, quaternary: nil, fallback: vaticanBio),
                popularQuote: nil,
                imageURL: wikipediaSaint?.imageURL,
                wikipediaTitle: wikipediaSaint?.wikipediaTitle ?? franciscanSource.canonicalName,
                sections: mergedSections.isEmpty ? [SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: bestShortBio(primary: profile?.shortBio, secondary: franciscanSource.shortBio, tertiary: wikipediaSaint?.shortBio, quaternary: nil, fallback: vaticanBio))] : mergedSections,
                fetchedDate: date
            )
        }

        if let wikipediaSaint {
            let mergedSections = applyingProfileOverrides(
                profileSections,
                to: mergedSections(primary: wikipediaSaint.sections, fallback: [])
            )
            return Saint(
                canonicalName: profile?.canonicalName ?? wikipediaSaint.canonicalName,
                feastDay: wikipediaSaint.feastDay,
                feastMonth: wikipediaSaint.feastMonth,
                feastDayOfMonth: wikipediaSaint.feastDayOfMonth,
                timePeriod: firstNonEmpty(profile?.timePeriod, wikipediaSaint.timePeriod),
                shortBio: bestShortBio(primary: profile?.shortBio, secondary: wikipediaSaint.shortBio, tertiary: nil, quaternary: nil, fallback: vaticanBio),
                popularQuote: wikipediaSaint.popularQuote,
                imageURL: wikipediaSaint.imageURL,
                wikipediaTitle: wikipediaSaint.wikipediaTitle,
                sections: mergedSections.isEmpty ? [SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: bestShortBio(primary: profile?.shortBio, secondary: wikipediaSaint.shortBio, tertiary: nil, quaternary: nil, fallback: vaticanBio))] : mergedSections,
                fetchedDate: date
            )
        }

        return fallbackSaint(name: profile?.canonicalName ?? originalName, shortBio: bestShortBio(primary: profile?.shortBio, secondary: vaticanBio, tertiary: nil, quaternary: nil, fallback: vaticanBio), profileSections: profileSections, timePeriod: profile?.timePeriod, date: date)
    }

    private func verifiedMatch(for originalName: String, candidate: Saint, fallbackBio: String, date: Date) -> Saint {
        guard isLikelySameSaint(originalName: originalName, candidateName: candidate.canonicalName) ||
                isLikelySameSaint(originalName: originalName, candidateName: candidate.wikipediaTitle) else {
            return fallbackSaint(name: originalName, shortBio: fallbackBio, profileSections: [], timePeriod: nil, date: date)
        }
        return candidate
    }

    private func saintWithCanonicalIdentity(
        _ saint: Saint,
        originalName: String,
        profile: SaintProfileRecord?,
        fallbackRecord: SaintCardFallbackRecord?
    ) -> Saint {
        let canonicalName = resolvedCanonicalName(
            saint: saint,
            originalName: originalName,
            profile: profile,
            fallbackRecord: fallbackRecord
        )
        let wikipediaTitle = resolvedWikipediaTitle(
            saint: saint,
            canonicalName: canonicalName,
            originalName: originalName
        )

        guard canonicalName != saint.canonicalName || wikipediaTitle != saint.wikipediaTitle else {
            return saint
        }

        return Saint(
            canonicalName: canonicalName,
            feastDay: saint.feastDay,
            feastMonth: saint.feastMonth,
            feastDayOfMonth: saint.feastDayOfMonth,
            timePeriod: saint.timePeriod,
            shortBio: saint.shortBio,
            popularQuote: saint.popularQuote,
            imageURL: saint.imageURL,
            wikipediaTitle: wikipediaTitle,
            sections: saint.sections,
            fetchedDate: saint.fetchedDate
        )
    }

    private func resolvedCanonicalName(
        saint: Saint,
        originalName: String,
        profile: SaintProfileRecord?,
        fallbackRecord: SaintCardFallbackRecord?
    ) -> String {
        let curatedNames: [String] = [
            profile?.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines),
            fallbackRecord?.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        if let curated = curatedNames.first {
            return curated
        }

        let candidate = saint.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasReliableCanonicalName(candidate, comparedTo: originalName),
           isLikelySameSaint(originalName: originalName, candidateName: candidate) {
            return candidate
        }

        return originalName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedWikipediaTitle(saint: Saint, canonicalName: String, originalName: String) -> String {
        let candidate = saint.wikipediaTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return canonicalName }

        if hasReliableCanonicalName(candidate, comparedTo: originalName),
           isLikelySameSaint(originalName: originalName, candidateName: candidate) {
            return candidate
        }

        return canonicalName
    }

    private func isLikelySameSaint(originalName: String, candidateName: String) -> Bool {
        let originalTokens = significantTokens(in: normalizedSaintName(originalName))
        let candidateTokens = significantTokens(in: normalizedSaintName(candidateName))

        guard !originalTokens.isEmpty, !candidateTokens.isEmpty else {
            return false
        }

        let overlap = Set(originalTokens).intersection(candidateTokens).count
        if overlap == 0 {
            return false
        }

        if originalTokens.count == 1 {
            return candidateTokens.count == 1 && overlap == 1
        }

        if overlap >= min(2, originalTokens.count) {
            return true
        }

        return originalTokens.first == candidateTokens.first && overlap == originalTokens.count - 1
    }

    private func hasReliableCanonicalName(_ candidateName: String, comparedTo originalName: String) -> Bool {
        let trimmed = candidateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if normalizedSaintName(trimmed) == normalizedSaintName(originalName) {
            return true
        }

        return !isSuspiciousCandidateName(trimmed, comparedTo: originalName)
    }

    private func isSuspiciousCandidateName(_ candidateName: String, comparedTo originalName: String) -> Bool {
        let candidateTokens = significantTokens(in: normalizedSaintName(candidateName))
        let originalTokens = significantTokens(in: normalizedSaintName(originalName))

        guard !candidateTokens.isEmpty else { return true }
        guard !originalTokens.isEmpty else { return false }

        if candidateTokens.count == 1, let token = candidateTokens.first {
            if token.count <= 3 && originalTokens.count >= 1 {
                return true
            }

            if originalTokens.count > 1 && !originalTokens.contains(token) {
                return true
            }
        }

        return false
    }

    private func normalizedSaintName(_ value: String) -> String {
        let simplified = value
            .replacingOccurrences(of: "St.", with: "Saint", options: .caseInsensitive)
            .replacingOccurrences(of: ", Doctor of the Church", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ", Bishop", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ", Priest", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ", Martyr", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ", Religious", with: "", options: .caseInsensitive)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        let compact = simplified
            .replacingOccurrences(of: #"bishop of ([a-z ]+?) and .*"#, with: "of $1", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return compact
    }

    private func significantTokens(in value: String) -> [String] {
        let stopWords: Set<String> = ["saint", "st", "of", "the", "and", "de", "la", "le", "doctor", "church", "bishop", "priest", "martyr", "religious", "deacon", "founder", "brothers", "christian", "schools", "spouse", "blessed", "virgin", "patron", "universal"]
        return value
            .split(separator: " ")
            .map(String.init)
            .filter { !stopWords.contains($0) && $0.count > 1 }
    }

    private func mergedSections(primary: [SaintSection], fallback: [SaintSection]) -> [SaintSection] {
        var sectionsByKind: [SectionKind: SaintSection] = [:]

        for section in primary where !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sectionsByKind[section.kind] = section
        }

        for section in fallback where !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard sectionsByKind[section.kind] == nil else { continue }
            sectionsByKind[section.kind] = section
        }

        let order: [SectionKind] = [.biography, .patronages, .miracles, .writings, .canonization, .other]
        return order.compactMap { sectionsByKind[$0] }
    }

    private func applyingProfileOverrides(_ overrides: [SaintSection], to sections: [SaintSection]) -> [SaintSection] {
        guard !overrides.isEmpty else { return sections }

        var sectionsByKind: [SectionKind: SaintSection] = [:]
        for section in sections where !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sectionsByKind[section.kind] = section
        }

        for override in overrides where !override.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sectionsByKind[override.kind] = override
        }

        let order: [SectionKind] = [.biography, .patronages, .miracles, .writings, .canonization, .other]
        return order.compactMap { sectionsByKind[$0] }
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func bestShortBio(primary: String?, secondary: String?, tertiary: String?, quaternary: String?, fallback: String) -> String {
        for candidate in [primary, secondary, tertiary, quaternary] {
            let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty {
                return value
            }
        }
        return fallback
    }

    private func resolvedName(primary: String?, secondary: String?, tertiary: String?, fallback: String) -> String {
        for candidate in [primary, secondary, tertiary] {
            let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty {
                return value
            }
        }
        return fallback
    }

    private func feastDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    private func saintWithQuote(_ saint: Saint, originalName: String) -> Saint {
        guard saint.popularQuote == nil else { return saint }
        return Saint(
            canonicalName: saint.canonicalName,
            feastDay: saint.feastDay,
            feastMonth: saint.feastMonth,
            feastDayOfMonth: saint.feastDayOfMonth,
            timePeriod: saint.timePeriod,
            shortBio: saint.shortBio,
            popularQuote: quoteService.quote(forNames: [saint.canonicalName, saint.wikipediaTitle, originalName]),
            imageURL: saint.imageURL,
            wikipediaTitle: saint.wikipediaTitle,
            sections: saint.sections,
            fetchedDate: saint.fetchedDate
        )
    }

    private func saintEnsuringRequiredCards(_ saint: Saint, originalName: String, fallbackBio: String, date: Date) -> Saint {
        let names = [saint.canonicalName, saint.wikipediaTitle, originalName]
        let normalizedSections = saint.sections.filter { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let ensuredBio = ensuredShortBio(for: saint, fallbackBio: fallbackBio, date: date, names: names)
        let ensuredQuote = ensuredQuote(for: saint, names: names)
        let ensuredPatronages = ensuredPatronages(for: saint, names: names)

        var sectionsByKind: [SectionKind: SaintSection] = [:]
        for section in normalizedSections {
            sectionsByKind[section.kind] = section
        }

        let biographyBody = biographyBody(for: saint, fallback: ensuredBio)
        sectionsByKind[.biography] = SaintSection(
            id: sectionsByKind[.biography]?.id ?? UUID(),
            kind: .biography,
            heading: sectionsByKind[.biography]?.heading ?? "Biography",
            body: biographyBody
        )

        sectionsByKind[.patronages] = SaintSection(
            id: sectionsByKind[.patronages]?.id ?? UUID(),
            kind: .patronages,
            heading: sectionsByKind[.patronages]?.heading ?? "Patronages",
            body: ensuredPatronages
        )

        let order: [SectionKind] = [.biography, .patronages, .miracles, .writings, .canonization, .other]
        let completedSections = order.compactMap { sectionsByKind[$0] }

        return Saint(
            canonicalName: saint.canonicalName,
            feastDay: saint.feastDay,
            feastMonth: saint.feastMonth,
            feastDayOfMonth: saint.feastDayOfMonth,
            timePeriod: saint.timePeriod,
            shortBio: ensuredBio,
            popularQuote: ensuredQuote,
            imageURL: saint.imageURL,
            wikipediaTitle: saint.wikipediaTitle,
            sections: completedSections,
            fetchedDate: saint.fetchedDate
        )
    }

    private func ensuredShortBio(for saint: Saint, fallbackBio: String, date: Date, names: [String]) -> String {
        let candidates = [
            saint.shortBio,
            biographySectionText(in: saint.sections),
            cardFallbackService.shortBio(forNames: names),
            fallbackBio
        ]

        for candidate in candidates {
            let polished = polishedNarrativeText(candidate ?? "", sentenceLimit: 3)
            if !polished.isEmpty {
                return polished
            }
        }

        return "\(saint.canonicalName) is commemorated on \(feastDayString(for: date)) in the Catholic tradition."
    }

    private func ensuredQuote(for saint: Saint, names: [String]) -> String {
        let candidates = [
            saint.popularQuote,
            quoteService.quote(forNames: names),
            cardFallbackService.quote(forNames: names)
        ]

        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return "No verified quote is currently available for \(saint.canonicalName)."
    }

    private func ensuredPatronages(for saint: Saint, names: [String]) -> String {
        let candidates = [
            patronageSectionText(in: saint.sections),
            derivedPatronageText(from: saint.sections),
            cardFallbackService.patronages(forNames: names)
        ]

        for candidate in candidates {
            let polished = polishedNarrativeText(candidate ?? "", sentenceLimit: nil)
            if !polished.isEmpty {
                return polished
            }
        }

        return "Patronage information is not yet curated for this saint."
    }

    private func biographySectionText(in sections: [SaintSection]) -> String? {
        sections.first(where: { $0.kind == .biography })?.body
    }

    private func patronageSectionText(in sections: [SaintSection]) -> String? {
        sections.first(where: { $0.kind == .patronages })?.body
    }

    private func derivedPatronageText(from sections: [SaintSection]) -> String? {
        let allText = sections
            .map(\.body)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !allText.isEmpty else { return nil }

        let sentences = splitIntoSentences(allText).filter {
            let lower = $0.lowercased()
            return lower.contains("patron of") || lower.contains("patronage") || lower.contains("patron saint of") || lower.contains("patroness of")
        }

        let result = sentences.joined(separator: " ")
        return result.isEmpty ? nil : result
    }

    private func biographyBody(for saint: Saint, fallback: String) -> String {
        let existing = saint.sections
            .first(where: { $0.kind == .biography })?
            .body
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !existing.isEmpty {
            let polished = polishedBiographyBody(existing, fallback: fallback)
            if !polished.isEmpty {
                return polished
            }
        }

        return fallback
    }

    private func completionScore(for saint: Saint) -> Int {
        var score = 0

        if !saint.shortBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 1
        }

        if let quote = saint.popularQuote?.trimmingCharacters(in: .whitespacesAndNewlines), !quote.isEmpty {
            score += 1
        }

        if let patronages = saint.sections.first(where: { $0.kind == .patronages })?.body.trimmingCharacters(in: .whitespacesAndNewlines),
           !patronages.isEmpty {
            score += 1
        }

        return score
    }

    private func polishedSaint(_ saint: Saint) -> Saint {
        let polishedShortBio = polishedNarrativeText(saint.shortBio, sentenceLimit: 3)

        let polishedSections = saint.sections.map { section in
            let cleanedBody: String
            if section.kind == .biography {
                let biography = polishedBiographyBody(section.body, fallback: polishedShortBio)
                cleanedBody = biography.isEmpty ? polishedShortBio : biography
            } else if section.kind == .writings {
                cleanedBody = polishedWritingsText(section.body)
            } else {
                cleanedBody = polishedNarrativeText(section.body, sentenceLimit: nil)
            }

            return SaintSection(
                id: section.id,
                kind: section.kind,
                heading: section.heading,
                body: cleanedBody
            )
        }

        return Saint(
            canonicalName: saint.canonicalName,
            feastDay: saint.feastDay,
            feastMonth: saint.feastMonth,
            feastDayOfMonth: saint.feastDayOfMonth,
            timePeriod: saint.timePeriod,
            shortBio: polishedShortBio,
            popularQuote: saint.popularQuote,
            imageURL: saint.imageURL,
            wikipediaTitle: saint.wikipediaTitle,
            sections: polishedSections,
            fetchedDate: saint.fetchedDate
        )
    }

    private func polishedBiographyBody(_ text: String, fallback: String) -> String {
        let cleaned = polishedNarrativeText(text, sentenceLimit: nil)
        guard !cleaned.isEmpty else { return fallback }

        let lower = cleaned.lowercased()
        let junkMarkers = [
            "catholic encyclopedia:",
            "submit search",
            "search encyclopedia",
            "home encyclopedia",
            "home > catholic encyclopedia",
            "please help support the mission of new advent"
        ]

        if junkMarkers.contains(where: lower.contains) {
            return fallback
        }

        return cleaned
    }

    private func polishedWritingsText(_ text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cleaned = lines.map { line -> String in
            if line.hasPrefix("- ") {
                let value = String(line.dropFirst(2))
                return "- " + polishedNarrativeText(value, sentenceLimit: nil)
            }
            return polishedNarrativeText(line, sentenceLimit: nil)
        }

        return cleaned.joined(separator: "\n")
    }

    private func polishedNarrativeText(_ text: String, sentenceLimit: Int?) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        let replacements: [(String, String)] = [
            (#"(?i)catholic encyclopedia:\s*"#, ""),
            (#"(?i)\bsearch:\b"#, ""),
            (#"(?i)\bsubmit search\b"#, ""),
            (#"(?i)home\s+encyclopedia\s+summa\s+fathers\s+bible\s+library.*"#, ""),
            (#"(?i)home\s*>\s*catholic encyclopedia\s*>.*"#, ""),
            (#"(?m)^\s*-->\s*$"#, ""),
            (#"\[[0-9]+\]"#, "")
        ]

        for (pattern, replacement) in replacements {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        cleaned = cleaned
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+\."#, with: ".", options: .regularExpression)
            .replacingOccurrences(of: #"\s+,"#, with: ",", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let sentenceLimit {
            let sentences = splitIntoSentences(cleaned)
            if !sentences.isEmpty {
                let limited = sentences.prefix(sentenceLimit).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = limited.hasSuffix(".") || limited.hasSuffix("!") || limited.hasSuffix("?") ? limited : limited + "."
            }
        }

        return cleaned
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let pattern = #"(?<=[.!?])\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
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

    private func fallbackSaint(name: String, shortBio: String, profileSections: [SaintSection], timePeriod: String?, date: Date) -> Saint {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"

        return Saint(
            canonicalName: name,
            feastDay: dateFormatter.string(from: date),
            feastMonth: components.month ?? 1,
            feastDayOfMonth: components.day ?? 1,
            timePeriod: timePeriod,
            shortBio: shortBio,
            popularQuote: quoteService.quote(forNames: [name]),
            imageURL: nil,
            wikipediaTitle: name,
            sections: profileSections.isEmpty ? [SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: shortBio)] : mergedSections(primary: profileSections, fallback: [SaintSection(id: UUID(), kind: .biography, heading: "Biography", body: shortBio)]),
            fetchedDate: date
        )
    }
}
