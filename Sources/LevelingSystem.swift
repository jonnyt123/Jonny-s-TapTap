import Foundation

enum SongDifficulty: String, Codable {
    case easy
    case normal
    case hard
    case expert

    var baseXP: Int64 {
        switch self {
        case .easy: return 140
        case .normal: return 200
        case .hard: return 280
        case .expert: return 380
        }
    }
}

struct SongResult {
    let score: Int
    let maxScore: Int
    let accuracyPercent: Double
    let maxCombo: Int
    let misses: Int
    let grade: String
    let difficulty: SongDifficulty
}

struct LevelUpResult {
    let xpGained: Int64
    let oldLevel: Int
    let newLevel: Int
    let didLevelUp: Bool
    let totalXP: Int64
    let prevThreshold: Int64
    let nextThreshold: Int64
    let progressToNext: Double
}

struct XPConfig {
    let minXP: Int64 = 40
    let maxXP: Int64 = 1200
    let accuracyFloor: Double = 0.6
    let accuracyScale: Double = 0.9
    let comboDivisor: Double = 220.0
    let comboCap: Double = 0.5
    let missPenaltyDivisor: Double = 45.0
    let missPenaltyFloor: Double = 0.4

    func gradeBonus(_ grade: String) -> Double {
        switch grade.uppercased() {
        case "S": return 0.20
        case "A": return 0.10
        case "B": return 0.05
        case "C": return 0.0
        case "D": return -0.10
        default: return 0.0
        }
    }
}

enum LevelingSystem {
    static let config = XPConfig()

    static func awardXP(
        result: SongResult,
        totalXP: Int64,
        thresholds: [Int64]
    ) -> LevelUpResult {
        let gained = xpForResult(result)
        let newTotal = min(LevelingCurve.maxXP, max(0, totalXP + gained))
        let oldLevel = level(for: totalXP, thresholds: thresholds)
        let newLevel = level(for: newTotal, thresholds: thresholds)

        let prev = thresholds[min(newLevel, LevelingCurve.maxLevel)]
        let next = thresholds[min(newLevel + 1, LevelingCurve.maxLevel)]
        let progress: Double
        if next <= prev {
            progress = 1.0
        } else {
            progress = Double(newTotal - prev) / Double(next - prev)
        }

        return LevelUpResult(
            xpGained: gained,
            oldLevel: oldLevel,
            newLevel: newLevel,
            didLevelUp: newLevel > oldLevel,
            totalXP: newTotal,
            prevThreshold: prev,
            nextThreshold: next,
            progressToNext: min(max(progress, 0), 1)
        )
    }

    static func xpForResult(_ result: SongResult) -> Int64 {
        let base = Double(result.difficulty.baseXP)
        let accuracy = max(0.0, min(result.accuracyPercent, 100.0)) / 100.0
        let scoreRatio = result.maxScore > 0 ? Double(result.score) / Double(result.maxScore) : accuracy

        let accuracyFactor = config.accuracyFloor + accuracy * config.accuracyScale
        let gradeFactor = 1.0 + config.gradeBonus(result.grade)
        let comboFactor = 1.0 + min(Double(result.maxCombo) / config.comboDivisor, config.comboCap)
        let missPenalty = max(config.missPenaltyFloor, 1.0 - Double(result.misses) / config.missPenaltyDivisor)
        let scoreFactor = 0.85 + 0.3 * scoreRatio

        let raw = base * accuracyFactor * gradeFactor * comboFactor * missPenalty * scoreFactor
        let clamped = min(Double(config.maxXP), max(Double(config.minXP), raw))
        return Int64(clamped.rounded())
    }

    static func level(for totalXP: Int64, thresholds: [Int64]) -> Int {
        if totalXP >= LevelingCurve.maxXP { return LevelingCurve.maxLevel }
        var low = 1
        var high = LevelingCurve.maxLevel
        while low <= high {
            let mid = (low + high) / 2
            if thresholds[mid] <= totalXP {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return max(1, min(LevelingCurve.maxLevel, high))
    }
}
