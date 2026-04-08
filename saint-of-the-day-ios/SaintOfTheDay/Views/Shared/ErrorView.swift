import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cross.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.frescoRed.opacity(0.8))

            Text("Something went wrong")
                .font(.saintHeading)
                .foregroundStyle(Color.inkBrown)

            Text(message)
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onRetry) {
                Text("Try Again")
                    .font(.saintBody)
                    .foregroundStyle(Color.parchment)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.ancientGold)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .parchmentBackground()
    }
}
