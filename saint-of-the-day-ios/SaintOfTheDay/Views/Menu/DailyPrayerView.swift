import SwiftUI

struct DailyPrayerView: View {
    @State private var prayers: [DailyPrayer] = []
    @State private var index: Int = 0

    private var currentPrayer: DailyPrayer? {
        guard !prayers.isEmpty else { return nil }
        return prayers[index % prayers.count]
    }

    var body: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()

            if let prayer = currentPrayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Occasion badge
                        Text(prayer.occasion.uppercased())
                            .font(.saintCaption)
                            .foregroundStyle(Color.ancientGold)
                            .tracking(1.5)

                        // Prayer name
                        Text(prayer.name)
                            .font(.saintTitle)
                            .foregroundStyle(Color.inkBrown)

                        Divider()
                            .overlay(Color.ancientGold.opacity(0.4))

                        // Prayer text
                        Text(prayer.text)
                            .font(.saintBody)
                            .foregroundStyle(Color.inkBrown)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 40)

                        // Next prayer button
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                index = (index + 1) % prayers.count
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Next Prayer")
                                    .font(.saintCaption)
                                    .foregroundStyle(Color.ancientGold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.ancientGold)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 20)
                    }
                    .padding(28)
                }
            } else {
                ProgressView()
                    .tint(Color.ancientGold)
            }
        }
        .navigationTitle("Daily Prayer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { loadPrayers() }
    }

    private func loadPrayers() {
        guard prayers.isEmpty,
              let url = Bundle.main.url(forResource: "prayers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DailyPrayer].self, from: data)
        else { return }

        prayers = decoded
        // Select today's prayer by weekday
        let weekday = Calendar.current.component(.weekday, from: Date())
        index = (weekday - 1) % decoded.count
    }
}
