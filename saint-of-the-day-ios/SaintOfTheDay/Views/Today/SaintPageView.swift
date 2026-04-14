import SwiftUI

struct SaintPageView: View {
    let saint: Saint
    let dateLabel: String
    @Binding var navigationPath: NavigationPath
    let onRefresh: () async -> Void

    private var featuredQuote: String {
        if let quote = saint.popularQuote?.trimmingCharacters(in: .whitespacesAndNewlines), !quote.isEmpty {
            return quote
        }

        let fallback = saint.shortBio
            .components(separatedBy: ". ")
            .prefix(2)
            .joined(separator: ". ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if fallback.isEmpty {
            return saint.canonicalName
        }
        return fallback.hasSuffix(".") ? fallback : fallback + "."
    }

    private var orderedSections: [SaintSection] {
        [
            sectionOrPlaceholder(
                kind: .patronages,
                heading: "Patron of",
                placeholder: "No patronage information is currently available for this saint."
            ),
            sectionOrPlaceholder(
                kind: .biography,
                heading: "Bio",
                placeholder: saint.shortBio
            ),
            sectionOrPlaceholder(
                kind: .miracles,
                heading: "Miracles",
                placeholder: "No miracle account is currently available for this saint."
            ),
            sectionOrPlaceholder(
                kind: .writings,
                heading: "Writings",
                placeholder: "No writings or recorded works are currently available for this saint."
            )
        ]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 12) {
                    SaintHeroCard(saint: saint)
                        .frame(height: UIScreen.main.bounds.height * 0.45)
                        .padding(.horizontal, 16)
                        .revealOnAppear()

                    SaintQuoteCard(quote: featuredQuote)
                        .padding(.horizontal, 16)
                        .revealOnAppear(delay: 0.10)

                    ForEach(Array(orderedSections.enumerated()), id: \.element.id) { index, section in
                        SaintSectionView(section: section)
                            .padding(.horizontal, 16)
                            .revealOnAppear(delay: 0.14 + (Double(index) * 0.05))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .refreshable {
                await onRefresh()
            }

            Text(dateLabel)
                .font(.saintCaption)
                .foregroundStyle(Color.parchment)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.ancientGold.opacity(0.85)))
                .padding(.top, 8)
                .padding(.trailing, 16)
        }
    }

    private func sectionOrPlaceholder(kind: SectionKind, heading: String, placeholder: String) -> SaintSection {
        let bodies = saint.sections
            .filter { $0.kind == kind }
            .map { $0.body.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let body = bodies.isEmpty ? placeholder : bodies.joined(separator: "\n\n")

        return SaintSection(
            id: UUID(),
            kind: kind,
            heading: heading,
            body: body
        )
    }
}
