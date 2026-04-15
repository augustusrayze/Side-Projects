import Foundation
import WidgetKit

/// Shared data model — must stay in sync with WidgetSaintData in SaintOfTheDayWidget.swift.
struct WidgetSaintData: Codable {
    let name: String
    let feastDay: String
    let bioExcerpt: String
    let date: Date
}

/// Writes today's saint into the shared App Group UserDefaults so the
/// WidgetKit extension can display it without making its own network calls.
enum SaintWidgetDataBridge {
    private static let appGroupID = "group.com.augustusrayze.saintoftheday"
    private static let key = "widgetSaintData"

    static func update(from saint: Saint) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let data = WidgetSaintData(
            name: saint.canonicalName,
            feastDay: saint.feastDay,
            bioExcerpt: saint.shortBio,
            date: Date()
        )

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }

        // Tell the widget to refresh immediately
        WidgetCenter.shared.reloadTimelines(ofKind: "SaintOfTheDayWidget")
    }
}
