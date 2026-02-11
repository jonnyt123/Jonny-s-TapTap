import Foundation
import QuartzCore
import SpriteKit

struct NoteData {
    let laneIndex: Int
    let hitTimeSeconds: Double
    let sourceNote: Note?
}

enum HitGrade {
    case perfect
    case great
    case good
    case bad
    case miss
    case emptyTap
}

final class MechanicsCore {
    final class ActiveNote {
        let data: NoteData
        weak var node: SKNode?
        var resolved: Bool

        init(data: NoteData, node: SKNode?, resolved: Bool) {
            self.data = data
            self.node = node
            self.resolved = resolved
        }
    }

    var globalOffsetSeconds: Double = 0.0
    var spawnLeadSeconds: Double = 2.0

    let perfectWindowSeconds: Double = 0.030
    let greatWindowSeconds: Double = 0.055
    let goodWindowSeconds: Double = 0.085
    let badWindowSeconds: Double = 0.120
    let missWindowSeconds: Double = 0.120

    var chartNotes: [NoteData] = []
    var nextSpawnIndex: Int = 0
    var activeNotesByLane: [[ActiveNote]] = Array(repeating: [], count: 4)
    var maxSpawnPerUpdate: Int?

    var onSpawnNote: ((NoteData) -> SKNode?)?
    var onHitNote: ((NoteData, SKNode?, HitGrade) -> Void)?
    var onMissNote: ((NoteData, SKNode?) -> Void)?

    private var rawPlaybackTimeProvider: (() -> Double)?
    private var fallbackAudioStartTimestamp: CFTimeInterval?
    private var fallbackAudioStartDelaySeconds: Double = 0.0

    func configureChartNotes(fromExistingNotes notes: [Note], bpm: Double?, offsetSeconds: Double?) {
        // TODO: If chart note times are beats, convert using BPM + offsetSeconds.
        chartNotes = notes.map { note in
            NoteData(laneIndex: note.lane, hitTimeSeconds: note.time, sourceNote: note)
        }
        chartNotes.sort { $0.hitTimeSeconds < $1.hitTimeSeconds }
        nextSpawnIndex = 0
        activeNotesByLane = Array(repeating: [], count: 4)
    }

    func startTiming(
        rawPlaybackTimeProvider: @escaping () -> Double,
        audioStartTimestamp: CFTimeInterval? = nil,
        audioStartDelaySeconds: Double = 0.0
    ) {
        self.rawPlaybackTimeProvider = rawPlaybackTimeProvider
        if let audioStartTimestamp {
            fallbackAudioStartTimestamp = audioStartTimestamp
            fallbackAudioStartDelaySeconds = audioStartDelaySeconds
        } else {
            fallbackAudioStartTimestamp = CACurrentMediaTime()
            fallbackAudioStartDelaySeconds = audioStartDelaySeconds
            // TODO: Replace fallback timer with true audio playback time when available.
        }
    }

    func rawPlaybackTimeSeconds() -> Double? {
        rawPlaybackTimeProvider?()
    }

    func songTimeSeconds() -> Double {
        if let raw = rawPlaybackTimeProvider?() {
            return raw + globalOffsetSeconds
        }
        guard let fallbackAudioStartTimestamp else {
            return globalOffsetSeconds
        }
        let elapsed = CACurrentMediaTime() - fallbackAudioStartTimestamp - fallbackAudioStartDelaySeconds
        return max(0, elapsed) + globalOffsetSeconds
    }

    func update() {
        let now = songTimeSeconds()
        var spawned = 0

        while nextSpawnIndex < chartNotes.count &&
                chartNotes[nextSpawnIndex].hitTimeSeconds <= now + spawnLeadSeconds {
            if let maxSpawnPerUpdate, spawned >= maxSpawnPerUpdate {
                break
            }
            let data = chartNotes[nextSpawnIndex]
            let node = onSpawnNote?(data)
            let active = ActiveNote(data: data, node: node, resolved: false)
            if (0..<activeNotesByLane.count).contains(data.laneIndex) {
                activeNotesByLane[data.laneIndex].append(active)
            }
            nextSpawnIndex += 1
            spawned += 1
        }

        for lane in 0..<activeNotesByLane.count {
            var remaining: [ActiveNote] = []
            for active in activeNotesByLane[lane] {
                if active.resolved {
                    continue
                }
                if now > active.data.hitTimeSeconds + missWindowSeconds {
                    active.resolved = true
                    onMissNote?(active.data, active.node)
                } else {
                    remaining.append(active)
                }
            }
            activeNotesByLane[lane] = remaining
        }
    }

    func handleTap(laneIndex: Int) -> HitGrade {
        guard (0..<activeNotesByLane.count).contains(laneIndex) else {
            return .emptyTap
        }

        let now = songTimeSeconds()
        let eligible = activeNotesByLane[laneIndex].filter {
            !$0.resolved && $0.data.hitTimeSeconds >= now - missWindowSeconds
        }

        guard let target = eligible.min(by: { $0.data.hitTimeSeconds < $1.data.hitTimeSeconds }) else {
            return .emptyTap
        }

        let absDelta = abs(now - target.data.hitTimeSeconds)
        guard let grade = GameplayTiming.hitGrade(
            absDeltaSeconds: absDelta,
            perfect: perfectWindowSeconds,
            great: greatWindowSeconds,
            good: goodWindowSeconds,
            bad: badWindowSeconds,
            miss: missWindowSeconds
        ) else {
            return .emptyTap
        }

        target.resolved = true
        onHitNote?(target.data, target.node, grade)
        activeNotesByLane[laneIndex].removeAll { $0 === target }
        return grade
    }
}
