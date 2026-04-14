import SwiftUI

struct GuidedRosaryMeditationsView: View {
    private let mysteries: [RosaryMystery] = [
        .init(title: "Joyful Mysteries", meditation: "Pray through the hidden years of Christ with attention to humility, obedience, and the quiet holiness of family life."),
        .init(title: "Luminous Mysteries", meditation: "Meditate on Christ's public ministry and ask for the grace to follow him with clarity, courage, and love."),
        .init(title: "Sorrowful Mysteries", meditation: "Stay with Christ in his Passion and offer your sufferings to God with trust, repentance, and perseverance."),
        .init(title: "Glorious Mysteries", meditation: "Contemplate the Resurrection and the life of heaven, asking for hope, fidelity, and final perseverance.")
    ]

    var body: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Take each decade slowly, naming the mystery and resting in one grace you want to receive.")
                        .font(.saintBody)
                        .foregroundStyle(Color.inkBrown.opacity(0.8))
                        .lineSpacing(5)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    ForEach(mysteries) { mystery in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(mystery.title)
                                .font(.saintHeading)
                                .foregroundStyle(Color.inkBrown)

                            Text(mystery.meditation)
                                .font(.saintBody)
                                .foregroundStyle(Color.inkBrown.opacity(0.85))
                                .lineSpacing(5)
                        }
                        .padding(20)
                        .cardStyle()
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Guided Rosary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct RosaryMystery: Identifiable {
    let id = UUID()
    let title: String
    let meditation: String
}
