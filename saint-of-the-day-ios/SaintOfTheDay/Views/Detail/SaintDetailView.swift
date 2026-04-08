import SwiftUI

struct SaintDetailView: View {
    let saint: Saint

    private var articleURL: URL? {
        let encoded = saint.wikipediaTitle.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? saint.wikipediaTitle
        return URL(string: "https://en.wikipedia.org/wiki/\(encoded)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero image
                SaintImageView(imageURL: saint.imageURL, name: saint.canonicalName)
                    .padding(.top, 8)
                    .revealOnAppear()

                // Name and period header
                VStack(spacing: 6) {
                    Text(saint.canonicalName)
                        .font(.saintTitle)
                        .foregroundStyle(Color.inkBrown)
                        .multilineTextAlignment(.center)

                    Text("Feast Day: \(saint.feastDay)")
                        .font(.saintCaption)
                        .foregroundStyle(Color.ancientGold)

                    if let period = saint.timePeriod {
                        Text(period)
                            .font(.saintCaption)
                            .foregroundStyle(Color.inkBrown.opacity(0.65))
                    }
                }
                .padding(.horizontal, 16)
                .revealOnAppear(delay: 0.06)

                GoldDivider()
                    .padding(.horizontal, 16)
                    .revealOnAppear(delay: 0.10)

                // Content sections — staggered reveal
                let sections = saint.sections.filter { !$0.body.isEmpty }
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    SaintSectionView(section: section)
                        .padding(.horizontal, 16)
                        .revealOnAppear(delay: 0.14 + Double(index) * 0.07)
                }

                // Wikipedia attribution (required by CC BY-SA 4.0)
                if let url = articleURL {
                    VStack(spacing: 4) {
                        GoldDivider()
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.caption)
                                Text("Content sourced from Wikipedia")
                                    .font(.saintCaption)
                            }
                            .foregroundStyle(Color.inkBrown.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .revealOnAppear(delay: 0.14 + Double(sections.count) * 0.07)
                }
            }
        }
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle(saint.canonicalName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
