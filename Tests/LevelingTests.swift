import XCTest
@testable import RhythmTap

final class LevelingTests: XCTestCase {
    func testThresholdsMonotonicAndMax() {
        let thresholds = LevelingCurve.powerCurve(exponent: 2.2)
        XCTAssertEqual(thresholds[1], 0)
        XCTAssertEqual(thresholds[LevelingCurve.maxLevel], LevelingCurve.maxXP)
        for level in 2...LevelingCurve.maxLevel {
            XCTAssertGreaterThanOrEqual(thresholds[level], thresholds[level - 1])
        }
    }

    func testLevelAtBoundaries() {
        let thresholds = LevelingCurve.powerCurve(exponent: 2.2)
        XCTAssertEqual(LevelingSystem.level(for: 0, thresholds: thresholds), 1)
        XCTAssertEqual(LevelingSystem.level(for: thresholds[2], thresholds: thresholds), 2)
        XCTAssertEqual(LevelingSystem.level(for: thresholds[50], thresholds: thresholds), 50)
        XCTAssertEqual(LevelingSystem.level(for: LevelingCurve.maxXP, thresholds: thresholds), 99)
        XCTAssertEqual(LevelingSystem.level(for: LevelingCurve.maxXP + 1000, thresholds: thresholds), 99)
    }

    func testXPFormulaClamp() {
        let result = SongResult(
            score: 0,
            maxScore: 1000,
            accuracyPercent: 0,
            maxCombo: 0,
            misses: 999,
            grade: "F",
            difficulty: .easy,
            totalNotes: 50
        )
        let (xp, _) = LevelingSystem.xpForResultWithBreakdown(result)
        XCTAssertGreaterThanOrEqual(xp, LevelingSystem.config.minXP)
        XCTAssertLessThanOrEqual(xp, LevelingSystem.config.maxXP)
    }

    func testXPFormulaCanonical() {
        let result = SongResult(
            score: 85000,
            maxScore: 100000,
            accuracyPercent: 90,
            maxCombo: 45,
            misses: 2,
            grade: "A",
            difficulty: .normal,
            totalNotes: 200
        )
        let (xp, breakdown) = LevelingSystem.xpForResultWithBreakdown(result)
        XCTAssertGreaterThanOrEqual(xp, LevelingSystem.config.minXP)
        XCTAssertLessThanOrEqual(xp, LevelingSystem.config.maxXP)
        XCTAssertEqual(breakdown.total, xp)
        XCTAssertEqual(breakdown.base, 180)
        XCTAssertGreaterThan(xp, 150, "Good performance should yield substantial XP")
    }

    func testLevelUpWhenCrossingThreshold() {
        let thresholds = LevelingCurve.defaultThresholds
        let result = SongResult(
            score: 100000,
            maxScore: 100000,
            accuracyPercent: 100,
            maxCombo: 100,
            misses: 0,
            grade: "S",
            difficulty: .expert,
            totalNotes: 300
        )
        let justUnderLevel2 = thresholds[2] - 1
        let output = LevelingSystem.awardXP(result: result, totalXP: justUnderLevel2, thresholds: thresholds)
        XCTAssertTrue(output.didLevelUp)
        XCTAssertEqual(output.newLevel, 2)
        XCTAssertEqual(output.oldLevel, 1)
    }

    func testProgressionTierNames() {
        XCTAssertEqual(ProgressionTier.rankName(for: 1), "Rookie")
        XCTAssertEqual(ProgressionTier.rankName(for: 12), "Rookie")
        XCTAssertEqual(ProgressionTier.rankName(for: 13), "Striker")
        XCTAssertEqual(ProgressionTier.rankName(for: 27), "Virtuoso")
        XCTAssertEqual(ProgressionTier.rankName(for: 43), "Ace")
        XCTAssertEqual(ProgressionTier.rankName(for: 63), "Master")
        XCTAssertEqual(ProgressionTier.rankName(for: 81), "Legend")
        XCTAssertEqual(ProgressionTier.rankName(for: 99), "Legend")
    }
}
