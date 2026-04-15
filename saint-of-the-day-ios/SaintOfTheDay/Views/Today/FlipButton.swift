import SwiftUI
import UIKit

struct FlipButton: View {
    let isShowingYesterday: Bool
    let isLoading: Bool
    let action: () -> Void

    private var symbolName: String {
        isShowingYesterday ? "chevron.right.2" : "chevron.left.2"
    }

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(Color.ancientGold.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

                if isLoading {
                    ProgressView()
                        .tint(Color.ancientGold)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.inkBrown)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isShowingYesterday)
        .accessibilityLabel(isShowingYesterday ? "Return to today's saint" : "View yesterday's saint")
        .accessibilityHint(isLoading ? "Loading" : "")
    }
}
