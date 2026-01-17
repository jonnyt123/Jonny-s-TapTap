import Foundation
import GameKit

final class LeaderboardService {
    static let shared = LeaderboardService()
    private let store = LeaderboardStore()

    private init() {}

    func submit(result: GCSongResult) {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        let scoreValue = Int64(result.score)
        let accuracyValue = Int64((result.accuracyPercent * 100.0).rounded())
        let comboValue = Int64(result.maxCombo)

        if let diffBoard = GameCenterConfiguration.scoreLeaderboardID(for: result.difficulty) {
            submitIfImproved(leaderboardID: diffBoard, value: scoreValue)
        }

        _ = accuracyValue
        _ = comboValue
    }

    private func submitIfImproved(leaderboardID: String, value: Int64) {
        let previous = store.bestValue(for: leaderboardID)
        guard value > previous else { return }
        store.setBestValue(value, for: leaderboardID)

        GKLeaderboard.submitScore(
            Int(value),
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID]
        ) { error in
            if let error {
                print("GC submit failed \(leaderboardID): \(error.localizedDescription)")
            } else {
                print("GC submitted \(leaderboardID): \(value)")
            }
        }
    }
}

private final class LeaderboardStore {
    private let keyPrefix = "gc_best_"

    func bestValue(for leaderboardID: String) -> Int64 {
        Int64(UserDefaults.standard.integer(forKey: keyPrefix + leaderboardID))
    }

    func setBestValue(_ value: Int64, for leaderboardID: String) {
        UserDefaults.standard.set(Int(value), forKey: keyPrefix + leaderboardID)
    }
}
