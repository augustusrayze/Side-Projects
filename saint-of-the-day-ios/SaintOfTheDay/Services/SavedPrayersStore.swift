import Foundation
import Observation

@Observable
final class SavedPrayersStore {
    static let shared = SavedPrayersStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "saved-prayers-v1"

    private(set) var savedPrayers: [DailyPrayer] = []

    private init() {
        load()
    }

    func contains(_ prayer: DailyPrayer) -> Bool {
        savedPrayers.contains { $0.id == prayer.id }
    }

    func toggle(_ prayer: DailyPrayer) {
        if contains(prayer) {
            remove(prayer)
        } else {
            save(prayer)
        }
    }

    func remove(_ prayer: DailyPrayer) {
        savedPrayers.removeAll { $0.id == prayer.id }
        persist()
    }

    private func save(_ prayer: DailyPrayer) {
        savedPrayers.removeAll { $0.id == prayer.id }
        savedPrayers.insert(prayer, at: 0)
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let prayers = try? JSONDecoder().decode([DailyPrayer].self, from: data) else {
            savedPrayers = []
            return
        }
        savedPrayers = prayers
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedPrayers) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
