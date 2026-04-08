import SwiftUI

struct DailyReadingsView: View {
    @State private var readings: DailyReadings? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.ancientGold)
                    Text("Loading readings…")
                        .font(.saintCaption)
                        .foregroundStyle(Color.inkBrown.opacity(0.6))
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.frescoRed)
                    Text(error)
                        .font(.saintCaption)
                        .foregroundStyle(Color.inkBrown.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await load() }
                    }
                    .font(.saintCaption)
                    .foregroundStyle(Color.ancientGold)
                }
                .padding(40)
            } else if let readings {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(formattedDate)
                            .font(.saintCaption)
                            .foregroundStyle(Color.ancientGold)
                            .tracking(1.0)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        ForEach(readings.readings) { reading in
                            ReadingCard(reading: reading)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationTitle("Mass Readings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            readings = try await ReadingsService.shared.fetchReadings(for: Date())
        } catch {
            errorMessage = "Could not load today's readings.\nPlease check your connection."
        }
        isLoading = false
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        return fmt.string(from: Date()).uppercased()
    }
}

// MARK: - Reading Card

private struct ReadingCard: View {
    let reading: Reading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.ancientGold)
                Text(reading.title.uppercased())
                    .font(.saintCaption)
                    .foregroundStyle(Color.ancientGold)
                    .tracking(1.0)
            }

            Text(reading.reference)
                .font(.saintHeading)
                .foregroundStyle(Color.inkBrown)

            Text(reading.text)
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown.opacity(0.85))
                .lineSpacing(5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.vellumShadow.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.ancientGold.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
    }

    private var iconName: String {
        switch reading.type {
        case "psaume":   return "music.note"
        case "evangile": return "cross.fill"
        default:         return "book.fill"
        }
    }
}
