import Foundation
import Observation

@Observable
final class SavedSaintsStore {
    static let shared = SavedSaintsStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "saved-saints-v1"

    private(set) var savedSaints: [Saint] = []

    private init() {
        load()
    }

    func contains(_ saint: Saint) -> Bool {
        savedSaints.contains { $0.id == saint.id }
    }

    func toggle(_ saint: Saint) {
        if contains(saint) {
            remove(saint)
        } else {
            save(saint)
        }
    }

    func remove(_ saint: Saint) {
        savedSaints.removeAll { $0.id == saint.id }
        persist()
    }

    private func save(_ saint: Saint) {
        savedSaints.removeAll { $0.id == saint.id }
        savedSaints.insert(saint, at: 0)
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let saints = try? JSONDecoder().decode([Saint].self, from: data) else {
            savedSaints = []
            return
        }
        savedSaints = saints
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedSaints) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
