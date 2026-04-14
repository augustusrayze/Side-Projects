import SwiftUI

struct QuickBioSnippet: View {
    let saint: Saint

    private var displayBio: String {
        let trimmed = saint.shortBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "\(saint.canonicalName) is commemorated in the Catholic tradition."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.ancientGold)
                Text("About")
                    .font(.saintHeading)
                    .foregroundStyle(Color.inkBrown)
                Spacer()
            }

            GoldDivider()

            Text(displayBio)
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown)
                .lineSpacing(4)
        }
        .padding(16)
        .cardStyle()
    }
}
