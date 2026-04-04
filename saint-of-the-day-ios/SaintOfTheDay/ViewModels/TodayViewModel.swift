import Foundation
import Observation

@Observable
final class TodayViewModel {

    // MARK: - Flip State
    var isShowingYesterday: Bool = false

    // MARK: - Repositories
    let todayRepo: SaintRepository
    let yesterdayRepo: SaintRepository

    init() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        self.todayRepo = SaintRepository(date: today)
        self.yesterdayRepo = SaintRepository(date: yesterday)
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

    // MARK: - Actions
    func loadToday() async {
        await todayRepo.fetchIfNeeded()
    }

    func refreshToday() async {
        await todayRepo.refresh()
    }

    func loadYesterdayIfNeeded() async {
        await yesterdayRepo.fetchIfNeeded()
    }

    func retryYesterday() async {
        await yesterdayRepo.refresh()
    }

    func flip() {
        isShowingYesterday.toggle()
        if isShowingYesterday {
            Task { await loadYesterdayIfNeeded() }
        }
    }
}
