import XCTest

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

    func testAwardClamp() {
        let thresholds = LevelingCurve.powerCurve(exponent: 2.2)
        let result = SongResult(
            score: 0,
            maxScore: 1000,
            accuracyPercent: 0,
            maxCombo: 0,
            misses: 999,
            grade: "D",
            difficulty: .easy
        )
        let output = LevelingSystem.awardXP(result: result, totalXP: 0, thresholds: thresholds)
        XCTAssertGreaterThanOrEqual(output.xpGained, LevelingSystem.config.minXP)
        XCTAssertLessThanOrEqual(output.xpGained, LevelingSystem.config.maxXP)
    }
}
