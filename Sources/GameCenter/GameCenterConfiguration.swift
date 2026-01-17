import Foundation

enum GameCenterConfiguration {
    static let scoreEasy = "com.jonny.taptap.score.easy"
    static let scoreMedium = "com.jonny.taptap.score.medium"
    static let scoreHard = "com.jonny.taptap.score.hard"
    static let scoreExtreme = "com.jonny.taptap.score.extreme"

    static func scoreLeaderboardID(for difficulty: String) -> String? {
        switch difficulty.lowercased() {
        case "easy": return scoreEasy
        case "medium": return scoreMedium
        case "hard": return scoreHard
        case "extreme": return scoreExtreme
        default: return nil
        }
    }
}
