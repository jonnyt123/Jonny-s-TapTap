import XCTest
@testable import RhythmTap

/// Unit tests for gameplay timing math (song time, spawn, hit windows, scroll).
/// To run: Add an iOS Unit Testing Bundle target, add this file to it, and set RhythmTap as the target to test.
final class TimingTests: XCTestCase {

    // MARK: - Authoritative song time (raw + offset)
    func testSongTimeFromRawAndOffset() {
        XCTAssertEqual(GameplayTiming.songTime(rawPlaybackSeconds: 0, offsetSeconds: 0), 0)
        XCTAssertEqual(GameplayTiming.songTime(rawPlaybackSeconds: 10, offsetSeconds: 0), 10)
        XCTAssertEqual(GameplayTiming.songTime(rawPlaybackSeconds: 10, offsetSeconds: 0.05), 10.05)
        XCTAssertEqual(GameplayTiming.songTime(rawPlaybackSeconds: 10, offsetSeconds: -0.02), 9.98)
        XCTAssertEqual(GameplayTiming.songTime(rawPlaybackSeconds: -0.1, offsetSeconds: 0), 0)
    }

    // MARK: - Spawn timing (note within lead window)
    func testShouldSpawnNote() {
        let lead: Double = 2.5
        // Note at 10s should spawn when now is 7.5 or later (10 <= 7.5 + 2.5)
        XCTAssertTrue(GameplayTiming.shouldSpawnNote(hitTimeSeconds: 10, nowSeconds: 7.5, leadSeconds: lead))
        XCTAssertTrue(GameplayTiming.shouldSpawnNote(hitTimeSeconds: 10, nowSeconds: 8, leadSeconds: lead))
        XCTAssertFalse(GameplayTiming.shouldSpawnNote(hitTimeSeconds: 10, nowSeconds: 7.4, leadSeconds: lead))
        // Exact boundary
        XCTAssertTrue(GameplayTiming.shouldSpawnNote(hitTimeSeconds: 5, nowSeconds: 3, leadSeconds: 2))
        XCTAssertFalse(GameplayTiming.shouldSpawnNote(hitTimeSeconds: 5, nowSeconds: 2.99, leadSeconds: 2))
    }

    // MARK: - Hit windows (MechanicsCore values: 30/55/85/120/120 ms)
    func testHitGradePerfect() {
        let p: Double = 0.030, g: Double = 0.055, o: Double = 0.085, b: Double = 0.120, m: Double = 0.120
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0, perfect: p, great: g, good: o, bad: b, miss: m), .perfect)
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.029, perfect: p, great: g, good: o, bad: b, miss: m), .perfect)
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.030, perfect: p, great: g, good: o, bad: b, miss: m), .perfect)
    }

    func testHitGradeGreat() {
        let p: Double = 0.030, g: Double = 0.055, o: Double = 0.085, b: Double = 0.120, m: Double = 0.120
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.031, perfect: p, great: g, good: o, bad: b, miss: m), .great)
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.055, perfect: p, great: g, good: o, bad: b, miss: m), .great)
    }

    func testHitGradeGood() {
        let p: Double = 0.030, g: Double = 0.055, o: Double = 0.085, b: Double = 0.120, m: Double = 0.120
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.056, perfect: p, great: g, good: o, bad: b, miss: m), .good)
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.085, perfect: p, great: g, good: o, bad: b, miss: m), .good)
    }

    func testHitGradeBadAndMiss() {
        let p: Double = 0.030, g: Double = 0.055, o: Double = 0.085, b: Double = 0.120, m: Double = 0.120
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.086, perfect: p, great: g, good: o, bad: b, miss: m), .bad)
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.120, perfect: p, great: g, good: o, bad: b, miss: m), .bad)
        XCTAssertEqual(GameplayTiming.hitGrade(absDeltaSeconds: 0.121, perfect: p, great: g, good: o, bad: b, miss: m), nil)
    }

    // MARK: - Scroll position (note Y from time delta and speed)
    func testNoteYPosition() {
        let hitLineY: CGFloat = 200
        let noteSpeed: CGFloat = 450
        // Note at 10s, song at 8s -> delta 2s -> Y = 200 + 2*450 = 1100 (above hit line)
        XCTAssertEqual(
            GameplayTiming.noteY(hitLineY: hitLineY, noteTimeSeconds: 10, songTimeSeconds: 8, noteSpeed: noteSpeed),
            200 + 2 * 450
        )
        // Note at hit time -> Y = hitLineY
        XCTAssertEqual(
            GameplayTiming.noteY(hitLineY: hitLineY, noteTimeSeconds: 5, songTimeSeconds: 5, noteSpeed: noteSpeed),
            200
        )
        // Note in the past -> below hit line
        XCTAssertEqual(
            GameplayTiming.noteY(hitLineY: hitLineY, noteTimeSeconds: 3, songTimeSeconds: 5, noteSpeed: noteSpeed),
            200 - 2 * 450
        )
    }
}
