import SwiftUI

/// The app icon design: white background, gold Vatican-style radial aura,
/// light blue Holy Spirit dove at center.
/// Used both as a visual reference and to generate AppIcon.png via AppIconExporter.
struct AppIconView: View {
    private let size: CGFloat = 1024

    var body: some View {
        ZStack {
            // 1. White background
            Color.white

            // 2. Warm gold radial glow behind the dove
            RadialGradient(
                stops: [
                    .init(color: Color(red: 0.965, green: 0.843, blue: 0.478).opacity(0.72), location: 0.0),
                    .init(color: Color(red: 0.965, green: 0.843, blue: 0.478).opacity(0.40), location: 0.28),
                    .init(color: Color(red: 0.965, green: 0.843, blue: 0.478).opacity(0.10), location: 0.52),
                    .init(color: .clear, location: 0.70),
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.46
            )

            // 3. 16 radiating gold rays (like the Vatican rib-vaults)
            ForEach(0..<16, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.42))
                    .frame(width: size * 0.010, height: size * 0.46)
                    .offset(y: -size * 0.23)
                    .rotationEffect(.degrees(Double(i) * 22.5))
            }

            // 4. Outer concentric gold ring
            Circle()
                .strokeBorder(
                    Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.55),
                    lineWidth: size * 0.0038
                )
                .frame(width: size * 0.54, height: size * 0.54)

            // 5. Inner concentric gold ring
            Circle()
                .strokeBorder(
                    Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.40),
                    lineWidth: size * 0.0028
                )
                .frame(width: size * 0.38, height: size * 0.38)

            // 6. Tiny center medallion circle
            Circle()
                .fill(Color(red: 0.965, green: 0.843, blue: 0.478).opacity(0.30))
                .frame(width: size * 0.26, height: size * 0.26)

            Circle()
                .strokeBorder(
                    Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.35),
                    lineWidth: size * 0.002
                )
                .frame(width: size * 0.26, height: size * 0.26)

            // 7. Holy Spirit dove — sky blue, centered
            Image(systemName: "bird.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.195, height: size * 0.195)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.529, green: 0.808, blue: 0.922), // sky blue #87CEE9
                            Color(red: 0.400, green: 0.718, blue: 0.871), // slightly deeper
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.25), radius: size * 0.015, x: 0, y: size * 0.006)
        }
        .frame(width: size, height: size)
    }
}

#Preview("App Icon 1024×1024") {
    AppIconView()
        .frame(width: 400, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 90))
}

#Preview("App Icon Small") {
    AppIconView()
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 13))
}
