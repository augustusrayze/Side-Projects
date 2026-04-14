import Foundation
import Observation

@Observable
final class PrayerViewModel {
    private let prayerService = PrayerService.shared
    private let vaticanService = VaticanNewsService()

    private(set) var selectedDate: Date
    private(set) var currentPrayer: DailyPrayer?
    private(set) var currentSaintName: String?
    private(set) var isLoading = false

    init(date: Date = Date()) {
        self.selectedDate = Calendar.current.startOfDay(for: date)
    }

    var dateLabel: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : formattedDate(selectedDate)
    }

    func load() async {
        await loadPrayer(for: selectedDate)
    }

    func selectDate(_ date: Date) async {
        let normalized = Calendar.current.startOfDay(for: date)
        selectedDate = normalized
        await loadPrayer(for: normalized)
    }

    func prayerLibrary() -> [DailyPrayer] {
        prayerService.library
    }

    private func loadPrayer(for date: Date) async {
        isLoading = true
        let saintName = try? await vaticanService.fetchSaint(for: date).name
        currentSaintName = saintName
        currentPrayer = prayerService.prayer(for: date, saintName: saintName)
        isLoading = false
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
