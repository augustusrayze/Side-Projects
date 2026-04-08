import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.ancientGold)
                .scaleEffect(1.4)
            Text("Loading today's saint...")
                .font(.saintCaption)
                .foregroundStyle(Color.inkBrown.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .parchmentBackground()
    }
}
