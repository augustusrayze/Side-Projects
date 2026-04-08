import SwiftUI

struct QuickBioSnippet: View {
    let saint: Saint

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

            Text(saint.shortBio)
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown)
                .lineSpacing(4)
        }
        .padding(16)
        .cardStyle()
    }
}
