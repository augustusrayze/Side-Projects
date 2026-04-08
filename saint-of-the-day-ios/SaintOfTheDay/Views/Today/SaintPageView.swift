import SwiftUI

struct SaintPageView: View {
    let saint: Saint
    let dateLabel: String
    @Binding var navigationPath: NavigationPath
    let onRefresh: () async -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    SaintHeroCard(saint: saint)
                        .frame(height: UIScreen.main.bounds.height * 0.45)
                        .padding(.horizontal, 16)
                        .revealOnAppear()

                    QuickBioSnippet(saint: saint)
                        .padding(.horizontal, 16)
                        .revealOnAppear(delay: 0.10)

                    Button {
                        navigationPath.append(saint)
                    } label: {
                        HStack {
                            Text("Read Full Story")
                                .font(.saintBody)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(Color.parchment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ancientGold)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                    .revealOnAppear(delay: 0.18)
                }
                .padding(.top, 8)
            }
            .refreshable {
                await onRefresh()
            }

            // Date badge — top trailing
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
}
