import Foundation
import Observation

enum LoadState {
    case idle
    case loading
    case loaded(Saint)
    case failed(Error)
}

@Observable
final class SaintRepository {
    private(set) var state: LoadState = .idle
    let date: Date

    private let vaticanService = VaticanNewsService()
    private let wikipediaService = WikipediaService()
    private let cacheService = CacheService()

    init(date: Date = Date()) {
        self.date = date
    }

    func fetchIfNeeded() async {
        if case .idle = state {
            await fetchSaint(for: date)
        }
    }

    func fetchSaint(for date: Date) async {
        if let cached = try? cacheService.load(for: date) {
            state = .loaded(cached)
            return
        }

        state = .loading

        do {
            let (name, _) = try await vaticanService.fetchSaint(for: date)
            let saint = try await wikipediaService.fetchSaint(named: name, for: date)
            try? cacheService.save(saint, for: date)
            state = .loaded(saint)
            // Update notification with saint image when today's saint loads
            if Calendar.current.isDateInToday(date), let imageURL = saint.imageURL {
                Task { await NotificationService.shared.updateNotificationImage(from: imageURL) }
            }
        } catch {
            if let stale = try? cacheService.load(for: date) {
                state = .loaded(stale)
            } else {
                state = .failed(error)
            }
        }
    }

    func refresh() async {
        state = .idle
        await fetchSaint(for: date)
    }
}
