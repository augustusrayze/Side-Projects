import SwiftUI

struct LiturgicalCalendarView: View {
    @State private var days: [LiturgicalDay] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.ancientGold)
                    Text("Loading calendar…")
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
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Season header
                        SeasonHeader(season: LiturgicalCalendarService.shared.currentSeason(from: days))
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 16)

                        // Grouped by month
                        ForEach(monthGroups, id: \.0) { month, monthDays in
                            Section {
                                ForEach(monthDays) { day in
                                    FeastRow(day: day)
                                    Divider()
                                        .overlay(Color.ancientGold.opacity(0.15))
                                        .padding(.leading, 64)
                                }
                            } header: {
                                Text(month.uppercased())
                                    .font(.saintCaption)
                                    .foregroundStyle(Color.ancientGold)
                                    .tracking(1.5)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationTitle("Liturgical Calendar")
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
            days = try await LiturgicalCalendarService.shared.fetchCalendar(for: currentYear)
        } catch {
            errorMessage = "Could not load the liturgical calendar.\nPlease check your connection."
        }
        isLoading = false
    }

    // Group days by month name
    private var monthGroups: [(String, [LiturgicalDay])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var groups: [(String, [LiturgicalDay])] = []
        var seen: [String: Int] = [:]
        for day in days {
            let key = fmt.string(from: day.date)
            if let idx = seen[key] {
                groups[idx].1.append(day)
            } else {
                seen[key] = groups.count
                groups.append((key, [day]))
            }
        }
        return groups
    }
}

// MARK: - Supporting Views

private struct SeasonHeader: View {
    let season: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(seasonColor)
                .frame(width: 12, height: 12)
            Text(season)
                .font(.saintHeading)
                .foregroundStyle(Color.inkBrown)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.vellumShadow.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.ancientGold.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private var seasonColor: Color {
        switch season {
        case "Advent":       return .purple
        case "Christmas":    return .white
        case "Lent":         return .purple
        case "Easter":       return .yellow
        default:             return .green
        }
    }
}

private struct FeastRow: View {
    let day: LiturgicalDay

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            // Date column
            VStack(spacing: 2) {
                Text(Self.weekdayFmt.string(from: day.date).uppercased())
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(Color.inkBrown.opacity(0.5))
                Text(Self.dayFmt.string(from: day.date))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.inkBrown)
            }
            .frame(width: 36)

            // Liturgical color swatch
            Circle()
                .fill(liturgicalColor)
                .frame(width: 8, height: 8)

            // Feast name
            VStack(alignment: .leading, spacing: 2) {
                Text(day.name)
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown)
                    .lineLimit(2)
                if day.isSolemnity {
                    Text("SOLEMNITY")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ancientGold)
                        .tracking(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.ancientGold.opacity(0.12))
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var liturgicalColor: Color {
        switch day.liturgicalColor {
        case "white":  return .white.opacity(0.8)
        case "red":    return Color.frescoRed
        case "green":  return .green.opacity(0.7)
        case "purple": return .purple.opacity(0.7)
        case "rose":   return .pink.opacity(0.6)
        default:       return Color.ancientGold.opacity(0.5)
        }
    }
}
