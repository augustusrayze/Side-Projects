import SwiftUI

struct SaintImageView: View {
    let imageURL: URL?
    let name: String

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure, .empty:
                Image("PlaceholderSaint")
                    .resizable()
                    .scaledToFit()
                    .opacity(0.6)
            @unknown default:
                Color.vellumShadow
                    .frame(height: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ancientGold.opacity(0.7), lineWidth: 2)
        )
        .shadow(color: Color.inkBrown.opacity(0.2), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 32)
    }
}
