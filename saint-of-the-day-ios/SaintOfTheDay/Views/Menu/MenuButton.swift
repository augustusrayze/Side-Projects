import SwiftUI
import UIKit

struct MenuButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.ancientGold.opacity(0.5), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.inkBrown)
            }
        }
        .buttonStyle(.plain)
    }
}
