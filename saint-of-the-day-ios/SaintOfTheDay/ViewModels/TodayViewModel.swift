import Foundation
import Observation

@Observable
final class TodayViewModel {

    // MARK: - Flip State
    var isShowingYesterday: Bool = false
    private(set) var selectedDate: Date

    // MARK: - Repositories
    private(set) var todayRepo: SaintRepository
    private(set) var yesterdayRepo: SaintRepository

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        self.selectedDate = today
        self.todayRepo = SaintRepository(date: today)
        self.yesterdayRepo = SaintRepository(date: Calendar.current.date(byAdding: .day, value: -1, to: today)!)
    }

    // MARK: - Today
    var todaySaint: Saint? {
        if case .loaded(let s) = todayRepo.state { return s }
        return nil
    }
    var isTodayLoading: Bool {
        if case .loading = todayRepo.state { return true }
        return false
    }
    var todayError: String? {
        if case .failed(let e) = todayRepo.state { return e.localizedDescription }
        return nil
    }
    var todayDateLabel: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : formattedDate(selectedDate)
    }

    // MARK: - Yesterday
    var yesterdaySaint: Saint? {
        if case .loaded(let s) = yesterdayRepo.state { return s }
        return nil
    }
    var isYesterdayLoading: Bool {
        if case .loading = yesterdayRepo.state { return true }
        return false
    }
    var yesterdayError: String? {
        if case .failed(let e) = yesterdayRepo.state { return e.localizedDescription }
        return nil
    }
    var previousDateLabel: String {
        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        return Calendar.current.isDateInToday(selectedDate) ? "Yesterday" : formattedDate(previousDate)
    }

    // MARK: - Actions
    func loadCurrentDate() async {
        await todayRepo.fetchIfNeeded()
    }

    func refreshCurrentDate() async {
        await todayRepo.refresh()
    }

    func loadPreviousDateIfNeeded() async {
        await yesterdayRepo.fetchIfNeeded()
    }

    func refreshPreviousDate() async {
        await yesterdayRepo.refresh()
    }

    func selectDate(_ date: Date) async {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        guard !Calendar.current.isDate(normalizedDate, inSameDayAs: selectedDate) else { return }
        selectedDate = normalizedDate
        isShowingYesterday = false
        configureRepositories(for: normalizedDate)
        await loadCurrentDate()
    }

    private func configureRepositories(for date: Date) {
        todayRepo = SaintRepository(date: date)
        yesterdayRepo = SaintRepository(
            date: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
