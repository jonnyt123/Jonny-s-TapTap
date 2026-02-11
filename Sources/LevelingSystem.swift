import Foundation

enum SongDifficulty: String, Codable {
    case easy
    case normal
    case hard
    case expert

    /// Base XP before modifiers (difficulty scaling).
    var baseXP: Int64 {
        switch self {
        case .easy: return 120
        case .normal: return 180
        case .hard: return 260
        case .expert: return 360
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
    /// Note count for length factor (longer charts = more XP potential). Default 100 for backward compat.
    let totalNotes: Int

    init(score: Int, maxScore: Int, accuracyPercent: Double, maxCombo: Int, misses: Int, grade: String, difficulty: SongDifficulty, totalNotes: Int = 100) {
        self.score = score
        self.maxScore = maxScore
        self.accuracyPercent = accuracyPercent
        self.maxCombo = maxCombo
        self.misses = misses
        self.grade = grade
        self.difficulty = difficulty
        self.totalNotes = totalNotes
    }
}

/// Per-component XP breakdown for post-song UI.
struct XPBreakdown {
    let base: Int64
    let accuracyBonus: Int64
    let comboBonus: Int64
    let lengthBonus: Int64
    let gradeBonus: Int64
    let total: Int64
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
    let breakdown: XPBreakdown?
    let rankName: String
}

/// Tiered ranks (original naming) for level bands. Purely cosmetic.
enum ProgressionTier {
    case rookie    // 1–12
    case striker   // 13–26
    case virtuoso // 27–42
    case ace       // 43–62
    case master    // 63–80
    case legend    // 81–99

    static func tier(for level: Int) -> ProgressionTier {
        switch level {
        case 1...12: return .rookie
        case 13...26: return .striker
        case 27...42: return .virtuoso
        case 43...62: return .ace
        case 63...80: return .master
        default: return .legend
        }
    }

    static func rankName(for level: Int) -> String {
        tier(for: level).displayName
    }

    var displayName: String {
        switch self {
        case .rookie: return "Rookie"
        case .striker: return "Striker"
        case .virtuoso: return "Virtuoso"
        case .ace: return "Ace"
        case .master: return "Master"
        case .legend: return "Legend"
        }
    }
}

struct XPConfig {
    let minXP: Int64 = 30
    let maxXP: Int64 = 800
    let accuracyFloor: Double = 0.5
    let accuracyScale: Double = 0.5
    let comboDivisor: Double = 200.0
    let comboCap: Double = 0.6
    let lengthNotesDivisor: Double = 400.0
    let lengthCap: Double = 0.8
    let lengthFloor: Double = 0.7

    func gradeMultiplier(_ grade: String) -> Double {
        switch grade.uppercased() {
        case "S": return 1.18
        case "A": return 1.10
        case "B": return 1.05
        case "C": return 1.0
        case "D": return 0.92
        default: return 0.85
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
        let (gained, breakdown) = xpForResultWithBreakdown(result)
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
            progressToNext: min(max(progress, 0), 1),
            breakdown: breakdown,
            rankName: ProgressionTier.rankName(for: newLevel)
        )
    }

    /// Returns (total XP, breakdown). Use for display and tests.
    static func xpForResultWithBreakdown(_ result: SongResult) -> (Int64, XPBreakdown) {
        let base = Int64(result.difficulty.baseXP)
        let accuracyNorm = max(0.0, min(result.accuracyPercent, 100.0)) / 100.0
        let accuracyFactor = config.accuracyFloor + accuracyNorm * config.accuracyScale
        let accuracyXP = Int64((Double(base) * (accuracyFactor - 1.0)).rounded())
        let baseAfterAccuracy = Int64((Double(base) * accuracyFactor).rounded())

        let comboFactor = 1.0 + min(Double(result.maxCombo) / config.comboDivisor, config.comboCap)
        let comboXP = Int64((Double(baseAfterAccuracy) * (comboFactor - 1.0)).rounded())
        let afterCombo = Int64((Double(baseAfterAccuracy) * comboFactor).rounded())

        let notes = max(0, result.totalNotes)
        let lengthFactor = config.lengthFloor + min(Double(notes) / config.lengthNotesDivisor, config.lengthCap)
        let lengthXP = Int64((Double(afterCombo) * (lengthFactor - 1.0)).rounded())
        let afterLength = Int64((Double(afterCombo) * lengthFactor).rounded())

        let gradeMult = config.gradeMultiplier(result.grade)
        let gradeXP = Int64((Double(afterLength) * (gradeMult - 1.0)).rounded())
        let rawTotal = Int64((Double(afterLength) * gradeMult).rounded())
        let clamped = min(config.maxXP, max(config.minXP, rawTotal))

        let breakdown = XPBreakdown(
            base: base,
            accuracyBonus: accuracyXP,
            comboBonus: comboXP,
            lengthBonus: lengthXP,
            gradeBonus: gradeXP,
            total: clamped
        )
        return (clamped, breakdown)
    }

    static func xpForResult(_ result: SongResult) -> Int64 {
        xpForResultWithBreakdown(result).0
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
