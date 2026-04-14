import Foundation

final class CacheService {
    private let calendar = Calendar.current
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load(for date: Date) throws -> Saint? {
        let url = cacheURL(for: date)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let saint = try decoder.decode(Saint.self, from: data)
        guard calendar.isDate(saint.fetchedDate, inSameDayAs: date) else { return nil }
        return saint
    }

    func save(_ saint: Saint, for date: Date) throws {
        let url = cacheURL(for: date)
        let data = try encoder.encode(saint)
        try data.write(to: url, options: .atomic)
    }

    private func cacheURL(for date: Date) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "saint-v7-\(formatter.string(from: date)).json"
        return dir.appendingPathComponent(filename)
    }
}
