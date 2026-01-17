import Foundation
import GameKit

final class ChallengeService {
    static let shared = ChallengeService()

    private init() {}

    func challengeScore(leaderboardID: String, value: Int64, message: String?) {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        // Challenges are now handled by the Game Center UI.
        // Present the leaderboard so players can issue challenges from there.
        GameCenterManager.shared.presentLeaderboards(leaderboardID: leaderboardID)
    }
}
