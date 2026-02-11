import Foundation
import CoreGraphics

/// Pure timing math for gameplay. Used by MechanicsCore and GameScene; unit-tested to prevent drift and sync bugs.
enum GameplayTiming {

    /// Song time from raw playback position + user offset (one authoritative clock).
    static func songTime(rawPlaybackSeconds: Double, offsetSeconds: Double) -> Double {
        max(0, rawPlaybackSeconds) + offsetSeconds
    }

    /// True if a note at hitTime should be spawned: it's within the lead window (now to now+lead).
    static func shouldSpawnNote(hitTimeSeconds: Double, nowSeconds: Double, leadSeconds: Double) -> Bool {
        hitTimeSeconds <= nowSeconds + leadSeconds
    }

    /// Hit grade from absolute delta (seconds) using MechanicsCore-style windows. Returns nil if outside miss window.
    static func hitGrade(
        absDeltaSeconds: Double,
        perfect: Double,
        great: Double,
        good: Double,
        bad: Double,
        miss: Double
    ) -> HitGrade? {
        guard absDeltaSeconds <= miss else { return nil }
        if absDeltaSeconds <= perfect { return .perfect }
        if absDeltaSeconds <= great { return .great }
        if absDeltaSeconds <= good { return .good }
        if absDeltaSeconds <= bad { return .bad }
        return .miss
    }

    /// Note Y position (pixels): hitLineY + (noteTime - songTime) * noteSpeed. Notes approach from above (positive delta = future).
    static func noteY(hitLineY: CGFloat, noteTimeSeconds: Double, songTimeSeconds: Double, noteSpeed: CGFloat) -> CGFloat {
        let delta = noteTimeSeconds - songTimeSeconds
        return hitLineY + CGFloat(delta) * noteSpeed
    }
}
