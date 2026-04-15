import WidgetKit
import SwiftUI

// MARK: - Shared data model (mirrored in SaintWidgetDataBridge.swift)

struct WidgetSaintData: Codable {
    let name: String
    let feastDay: String
    let bioExcerpt: String
    let date: Date

    static var placeholder: WidgetSaintData {
        WidgetSaintData(
            name: "Saint Francis of Assisi",
            feastDay: "October 4",
            bioExcerpt: "Founder of the Franciscan Order, patron of animals and the natural environment.",
            date: Date()
        )
    }

    static var empty: WidgetSaintData {
        WidgetSaintData(
            name: "Saint of the Day",
            feastDay: "Open app to load",
            bioExcerpt: "Open the app once to see today's featured saint here.",
            date: Date()
        )
    }
}

// MARK: - Timeline Provider

struct SaintProvider: TimelineProvider {
    private let appGroupID = "group.com.augustusrayze.saintoftheday"

    func placeholder(in context: Context) -> SaintEntry {
        SaintEntry(date: Date(), saintData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SaintEntry) -> Void) {
        completion(SaintEntry(date: Date(), saintData: loadSaintData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SaintEntry>) -> Void) {
        let entry = SaintEntry(date: Date(), saintData: loadSaintData())

        // Refresh shortly after midnight so tomorrow's saint appears on time
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 0
        components.minute = 5
        let nextMidnight = Calendar.current.date(from: components) ?? Date().addingTimeInterval(86_400)

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func loadSaintData() -> WidgetSaintData {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: "widgetSaintData"),
            let saint = try? JSONDecoder().decode(WidgetSaintData.self, from: data),
            Calendar.current.isDateInToday(saint.date)
        else { return .empty }
        return saint
    }
}

// MARK: - Timeline Entry

struct SaintEntry: TimelineEntry {
    let date: Date
    let saintData: WidgetSaintData
}

// MARK: - Widget Entry View (routes to size-specific layouts)

struct SaintWidgetEntryView: View {
    var entry: SaintProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(data: entry.saintData)
        case .systemMedium: MediumWidgetView(data: entry.saintData)
        case .systemLarge:  LargeWidgetView(data: entry.saintData)
        default:            SmallWidgetView(data: entry.saintData)
        }
    }
}

// MARK: - Color constants (hardcoded so ImageRenderer captures them correctly)

private enum W {
    static let parchment  = Color(red: 0.961, green: 0.902, blue: 0.784)
    static let gold       = Color(red: 0.722, green: 0.525, blue: 0.043)
    static let inkBrown   = Color(red: 0.239, green: 0.169, blue: 0.122)
}

// MARK: - Small (name + feast day)

private struct SmallWidgetView: View {
    let data: WidgetSaintData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "bird.fill")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(W.gold)

            Spacer()

            Text("SAINT OF THE DAY")
                .font(.system(size: 7.5, weight: .medium, design: .serif))
                .foregroundStyle(W.gold)
                .tracking(0.6)

            Text(data.name)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(W.inkBrown)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

            Text(data.feastDay)
                .font(.system(size: 10, weight: .regular, design: .serif))
                .foregroundStyle(W.gold)
                .padding(.top, 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(W.parchment)
    }
}

// MARK: - Medium (name + feast + bio excerpt)

private struct MediumWidgetView: View {
    let data: WidgetSaintData

    var body: some View {
        HStack(spacing: 14) {
            // Left — dove + wordmark
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(W.gold)

                Spacer()

                Text("SAINT\nOF THE\nDAY")
                    .font(.system(size: 7.5, weight: .medium, design: .serif))
                    .foregroundStyle(W.gold)
                    .tracking(0.4)
                    .lineSpacing(2)
            }
            .frame(width: 68)

            // Gold divider
            Rectangle()
                .fill(W.gold.opacity(0.35))
                .frame(width: 1)

            // Right — content
            VStack(alignment: .leading, spacing: 5) {
                Text(data.name)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(W.inkBrown)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(data.feastDay.uppercased())
                    .font(.system(size: 9, weight: .regular, design: .serif))
                    .foregroundStyle(W.gold)
                    .tracking(0.5)

                Rectangle()
                    .fill(W.gold.opacity(0.25))
                    .frame(height: 0.75)

                Text(data.bioExcerpt)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(W.inkBrown.opacity(0.82))
                    .lineLimit(3)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(W.parchment)
    }
}

// MARK: - Large (full layout)

private struct LargeWidgetView: View {
    let data: WidgetSaintData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Image(systemName: "bird.fill")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(W.gold)
                Spacer()
                Text("SAINT OF THE DAY")
                    .font(.system(size: 9, weight: .medium, design: .serif))
                    .foregroundStyle(W.gold)
                    .tracking(1.0)
            }

            Rectangle()
                .fill(W.gold.opacity(0.45))
                .frame(height: 0.75)

            // Saint name
            Text(data.name)
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(W.inkBrown)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            // Feast day
            Text(data.feastDay.uppercased())
                .font(.system(size: 10, weight: .regular, design: .serif))
                .foregroundStyle(W.gold)
                .tracking(0.8)

            Rectangle()
                .fill(W.gold.opacity(0.25))
                .frame(height: 0.75)

            // Bio
            Text(data.bioExcerpt)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(W.inkBrown.opacity(0.85))
                .lineLimit(7)
                .lineSpacing(3)

            Spacer()

            // Footer
            Text("Tap to open Saint of the Day")
                .font(.system(size: 9, weight: .regular, design: .serif))
                .foregroundStyle(W.gold.opacity(0.7))
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(W.parchment)
    }
}

// MARK: - Widget Configuration

struct SaintOfTheDayWidget: Widget {
    let kind = "SaintOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SaintProvider()) { entry in
            SaintWidgetEntryView(entry: entry)
                .containerBackground(W.parchment, for: .widget)
        }
        .configurationDisplayName("Saint of the Day")
        .description("Today's featured Catholic saint on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    SaintOfTheDayWidget()
} timeline: {
    SaintEntry(date: .now, saintData: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    SaintOfTheDayWidget()
} timeline: {
    SaintEntry(date: .now, saintData: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    SaintOfTheDayWidget()
} timeline: {
    SaintEntry(date: .now, saintData: .placeholder)
}
