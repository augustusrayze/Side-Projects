import SwiftUI

struct SaintHeroCard: View {
    let saint: Saint

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Saint image
                AsyncImage(url: saint.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        Image("PlaceholderSaint")
                            .resizable()
                            .scaledToFill()
                    @unknown default:
                        Color.vellumShadow
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Bottom gradient overlay
                LinearGradient(
                    colors: [Color.inkBrown.opacity(0.85), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: geo.size.height * 0.55)

                // Name and feast day
                VStack(alignment: .leading, spacing: 4) {
                    Text(saint.canonicalName)
                        .font(.saintDisplay)
                        .foregroundStyle(Color.parchment)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                    Text("Feast Day: \(saint.feastDay)")
                        .font(.saintCaption)
                        .foregroundStyle(Color.ancientGold)

                    if let period = saint.timePeriod {
                        Text(period)
                            .font(.saintCaption)
                            .foregroundStyle(Color.parchment.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.ancientGold.opacity(0.7), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.inkBrown.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
