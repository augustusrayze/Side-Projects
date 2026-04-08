import SwiftUI

struct SaintSectionView: View {
    let section: SaintSection

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

    // MARK: - Decorative Quote for Writings

    private var writingsBody: some View {
        ZStack(alignment: .topLeading) {
            // Large decorative open-quote in the background
            Text("\u{201C}")
                .font(.system(size: 80, weight: .light, design: .serif))
                .foregroundStyle(Color.ancientGold.opacity(0.22))
                .offset(x: -6, y: -14)
                .allowsHitTesting(false)

            Text(section.body)
                .font(.saintBody)
                .italic()
                .foregroundStyle(Color.inkBrown.opacity(0.9))
                .lineSpacing(6)
                .padding(.top, 22)
                .padding(.leading, 6)
        }
    }

    // MARK: - Icon

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
