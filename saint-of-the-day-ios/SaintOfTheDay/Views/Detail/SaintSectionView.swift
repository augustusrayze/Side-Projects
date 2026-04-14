import SwiftUI

struct SaintSectionView: View {
    let section: SaintSection

    private var writingLines: [String] {
        section.body
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var notableWorks: [String] {
        writingLines.filter { $0.hasPrefix("- ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var writingSummary: String {
        writingLines
            .filter { !$0.hasPrefix("- ") }
            .joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: section.kind))
                    .foregroundStyle(Color.ancientGold)
                    .frame(width: 20)
                Text(section.heading)
                    .font(.saintHeading)
                    .foregroundStyle(Color.inkBrown)
            }

            GoldDivider()

            if section.kind == .writings {
                writingsBody
            } else {
                Text(section.body)
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown)
                    .lineSpacing(5)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var writingsBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !notableWorks.isEmpty {
                Text("Notable works")
                    .font(.saintCaption)
                    .foregroundStyle(Color.ancientGold)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(notableWorks, id: \.self) { work in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Color.ancientGold)
                                .padding(.top, 7)

                            Text(work)
                                .font(.saintBody)
                                .foregroundStyle(Color.inkBrown.opacity(0.95))
                        }
                    }
                }
            }

            if !writingSummary.isEmpty {
                Text(writingSummary)
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown.opacity(0.9))
                    .lineSpacing(5)
            }
        }
    }

    private func icon(for kind: SectionKind) -> String {
        switch kind {
        case .biography:    return "person.fill"
        case .miracles:     return "sparkles"
        case .writings:     return "book.fill"
        case .patronages:   return "shield.fill"
        case .canonization: return "crown.fill"
        case .other:        return "info.circle"
        }
    }
}
