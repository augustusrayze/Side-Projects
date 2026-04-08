import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: phase - 0.25),
                            .init(color: .white.opacity(0.38), location: phase),
                            .init(color: .clear, location: phase + 0.25),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 2.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - SaintPageSkeleton

struct SaintPageSkeleton: View {
    private let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Hero card placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.vellumShadow.opacity(0.45))
                    .shimmer()
                    .frame(height: screenHeight * 0.45)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.ancientGold.opacity(0.2), lineWidth: 1)
                            .padding(.horizontal, 16)
                    )

                // Bio text lines
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.vellumShadow.opacity(0.35))
                            .shimmer()
                            .frame(maxWidth: i == 4 ? 180 : .infinity)
                            .frame(height: 14)
                    }
                }
                .padding(.horizontal, 20)

                // Button placeholder
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.vellumShadow.opacity(0.25))
                    .shimmer()
                    .frame(height: 48)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
    }
}
