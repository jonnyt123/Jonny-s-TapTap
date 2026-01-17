import Foundation

struct PlayerProgress: Codable {
    var totalXP: Int64
    var level: Int
    var updatedAt: Date
}

enum LevelingStore {
    private static let key = "playerProgress_v1"

    static func load() -> PlayerProgress {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(PlayerProgress.self, from: data) else {
            return PlayerProgress(totalXP: 0, level: 1, updatedAt: Date())
        }
        return decoded
    }

    static func save(_ progress: PlayerProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
