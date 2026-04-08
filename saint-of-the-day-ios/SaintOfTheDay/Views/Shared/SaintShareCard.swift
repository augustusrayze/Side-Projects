import SwiftUI

/// A static parchment card rendered to an image for sharing.
/// Uses no AsyncImage so ImageRenderer captures it reliably.
struct SaintShareCard: View {
    let saint: Saint

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.961, green: 0.902, blue: 0.784) // ParchmentBeige light

            VStack(alignment: .leading, spacing: 0) {
                // Top label
                HStack {
                    Text("✦  SAINT OF THE DAY  ✦")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .tracking(2.0)
                        .foregroundStyle(Color(red: 0.722, green: 0.525, blue: 0.043)) // AncientGold
                    Spacer()
                }
                .padding(.bottom, 28)

                // Saint name
                Text(saint.canonicalName)
                    .font(.system(size: 34, weight: .light, design: .serif))
                    .tracking(1.0)
                    .foregroundStyle(Color(red: 0.239, green: 0.169, blue: 0.122)) // InkBrown
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)

                // Feast day
                Text(saint.feastDay.uppercased())
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .tracking(1.5)
                    .italic()
                    .foregroundStyle(Color(red: 0.722, green: 0.525, blue: 0.043))
                    .padding(.bottom, 4)

                // Time period
                if let period = saint.timePeriod {
                    Text(period)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(Color(red: 0.239, green: 0.169, blue: 0.122).opacity(0.65))
                        .padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 20)
                }

                // Divider
                Rectangle()
                    .fill(Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.45))
                    .frame(height: 0.5)
                    .padding(.bottom, 20)

                // Short bio excerpt (max 4 lines)
                Text(saint.shortBio)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Color(red: 0.239, green: 0.169, blue: 0.122).opacity(0.85))
                    .lineSpacing(5)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Bottom divider + wordmark
                Rectangle()
                    .fill(Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.45))
                    .frame(height: 0.5)
                    .padding(.bottom, 12)

                Text("Saint of the Day")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .tracking(0.5)
                    .foregroundStyle(Color(red: 0.722, green: 0.525, blue: 0.043))
            }
            .padding(32)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.722, green: 0.525, blue: 0.043).opacity(0.6), lineWidth: 1.5)
                .padding(8)
        )
    }
}
