import SwiftUI

struct SaintQuoteCard: View {
    let quote: String

    private var displayQuote: String {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "No verified quote is currently available for this saint."
    }

    var body: some View {
        Text(displayQuote)
            .font(.saintBody)
            .italic()
            .foregroundStyle(Color.inkBrown)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardStyle()
    }
}
