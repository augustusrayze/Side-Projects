import Foundation
import Observation

enum RootTab: Hashable {
    case saints
    case prayer
    case saved
}

@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selectedTab: RootTab = .saints
    var requestedSaintDate: Date?
    var saintDateRequestID = UUID()
    var requestedPrayerDate: Date?
    var prayerDateRequestID = UUID()

    private init() {}

    func openSaints(for date: Date) {
        selectedTab = .saints
        requestedSaintDate = Calendar.current.startOfDay(for: date)
        saintDateRequestID = UUID()
    }

    func clearRequestedSaintDate() {
        requestedSaintDate = nil
    }

    func openPrayer(for date: Date? = nil) {
        selectedTab = .prayer
        requestedPrayerDate = date.map { Calendar.current.startOfDay(for: $0) }
        prayerDateRequestID = UUID()
    }

    func clearRequestedPrayerDate() {
        requestedPrayerDate = nil
    }
}
