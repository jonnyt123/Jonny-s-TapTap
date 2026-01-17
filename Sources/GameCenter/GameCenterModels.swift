import Foundation

struct GCSongResult: Codable {
    let songId: String
    let difficulty: String
    let score: Int
    let accuracyPercent: Double
    let maxCombo: Int
    let didFC: Bool
    let timestamp: Date
}

struct GCSubmitResult {
    let leaderboardID: String
    let value: Int64
    let submitted: Bool
}

enum GameCenterAuthState: Equatable {
    case idle
    case authenticating
    case authenticated(displayName: String)
    case notAuthenticated(reason: String)
}
