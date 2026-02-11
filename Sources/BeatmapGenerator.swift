import Foundation

private struct DifficultySettings {
    let avgNPS: Double
    let peakNPS: Double
    let floorNPS: Double
    let allowQuarter: Bool
    let allowEighth: Bool
    let allowSixteenth: Bool
    let sixteenthAccentsOnly: Bool
    let burstMaxBeats16: Double
    let chordChance: Double
    let repeatLaneMax: Int
    let minGapMsPerLane: Double
    let weights: (single: Double, alt: Double, sweep: Double, anchor: Double)
    let allowExtremeBreath: Bool
}

private struct DebugWindow {
    let start: Double
    let end: Double
    let targetNPS: Double
    let actualNPS: Double
    let notes: Int
}

private struct BeatNote: Hashable {
    let t: Double
    let lane: Int
    let type: String
}

private struct LCG {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
    }

    mutating func nextUInt() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        let value = nextUInt() >> 11
        return Double(value) / Double(1 << 53)
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt() % UInt64(upperBound))
    }
}

private enum SubdivisionMode {
    case quarter
    case eighth
    case sixteenth
    case eighthWithAccents
    case sixteenthWithBreath
}

func generateBeatmapJSON(
    difficulty: Difficulty,
    bpm: Double,
    durationSec: Double,
    offsetSec: Double,
    seed: Int
) -> String {
    let beatSec = 60.0 / bpm
    let quarter = beatSec
    let eighth = beatSec / 2.0
    let sixteenth = beatSec / 4.0
    let windowSec = 0.5

    let settings = settingsForDifficulty(difficulty)
    var rng = LCG(seed: seed)

    var notes: [BeatNote] = []
    var debugWindows: [DebugWindow] = []
    var prevTargetNPS = settings.avgNPS
    var sixteenthBurstDuration = 0.0
    var lastLaneTime = Array(repeating: -Double.greatestFiniteMagnitude, count: 4)
    var lastLane: Int = 0
    var repeatCount = 0
    var sweepIndex = 0
    var sweepDirection = 1

    let windowCount = Int(ceil(durationSec / windowSec))
    for w in 0..<windowCount {
        let wStart = Double(w) * windowSec
        let wEnd = min(durationSec, wStart + windowSec)
        let mid = (wStart + wEnd) * 0.5
        let m = npsMultiplier(at: mid)
        var targetNPS = clamp(settings.avgNPS * m, settings.floorNPS, settings.peakNPS)
        if w > 0 {
            targetNPS = lerp(prevTargetNPS, targetNPS, 0.15)
        }
        prevTargetNPS = targetNPS

        var mode = chooseSubdivisionMode(
            targetNPS: targetNPS,
            difficulty: difficulty,
            settings: settings,
            rng: &rng
        )

        let isSixteenthHeavy = (mode == .sixteenth || mode == .sixteenthWithBreath)
        if isSixteenthHeavy {
            sixteenthBurstDuration += windowSec
        } else {
            sixteenthBurstDuration = max(0, sixteenthBurstDuration - windowSec * 0.5)
        }

        let maxBurstDuration = settings.burstMaxBeats16 * beatSec
        if maxBurstDuration > 0, sixteenthBurstDuration > maxBurstDuration {
            mode = .eighth
            sixteenthBurstDuration = max(0, sixteenthBurstDuration - windowSec)
        }

        let candidateSlots = buildSlots(
            mode: mode,
            wStart: wStart,
            wEnd: wEnd,
            quarter: quarter,
            eighth: eighth,
            sixteenth: sixteenth
        )

        let notesNeeded = max(0, Int((targetNPS * windowSec).rounded()))
        let peakSegment = isPeakSegment(mid)
        let chosenSlots = selectSlots(
            candidateSlots: candidateSlots,
            count: notesNeeded,
            peakSegment: peakSegment,
            rng: &rng
        )

        var windowNotes: [BeatNote] = []
        var timeToNotes: [Double: Int] = [:]

        for slot in chosenSlots {
            let (created, lastState) = createNotesForSlot(
                time: slot,
                lastLane: lastLane,
                repeatCount: repeatCount,
                lastLaneTime: lastLaneTime,
                sweepIndex: sweepIndex,
                sweepDirection: sweepDirection,
                settings: settings,
                rng: &rng
            )
            if let created = created {
                for note in created {
                    if note.lane >= 0 && note.lane < 4 {
                        windowNotes.append(note)
                        timeToNotes[note.t, default: 0] += 1
                        lastLaneTime[note.lane] = note.t
                        if note.lane == lastLane {
                            repeatCount += 1
                        } else {
                            lastLane = note.lane
                            repeatCount = 1
                        }
                    }
                }
            }
            sweepIndex = lastState.sweepIndex
            sweepDirection = lastState.sweepDirection
        }

        windowNotes = enforceWindowNPS(
            windowNotes: windowNotes,
            targetNPS: targetNPS,
            windowSec: windowSec,
            wStart: wStart,
            wEnd: wEnd,
            candidateSlots: candidateSlots,
            settings: settings,
            lastLaneTime: &lastLaneTime,
            lastLane: &lastLane,
            repeatCount: &repeatCount,
            sweepIndex: &sweepIndex,
            sweepDirection: &sweepDirection,
            rng: &rng
        )

        notes.append(contentsOf: windowNotes)
        let actualNPS = windowNotes.count > 0 ? Double(windowNotes.count) / windowSec : 0.0
        debugWindows.append(DebugWindow(
            start: wStart,
            end: wEnd,
            targetNPS: roundTo3(targetNPS),
            actualNPS: roundTo3(actualNPS),
            notes: windowNotes.count
        ))
    }

    let deduped = dedupeNotes(notes)
    let clamped = deduped.map { note -> BeatNote in
        let t = clamp(note.t, 0, durationSec)
        let tFinal = clamp(t + offsetSec, 0, durationSec)
        return BeatNote(t: roundTo3(tFinal), lane: note.lane, type: note.type)
    }
    let sorted = clamped.sorted { a, b in
        if a.t == b.t { return a.lane < b.lane }
        return a.t < b.t
    }

    let json = buildJSON(
        bpm: bpm,
        durationSec: durationSec,
        offsetSec: offsetSec,
        difficulty: difficulty.rawValue,
        notes: sorted,
        windowSec: windowSec,
        debug: debugWindows
    )
    return json
}

func testBeatmapGeneratorPreview() {
    let json = generateBeatmapJSON(
        difficulty: .medium,
        bpm: 138,
        durationSec: 10.0,
        offsetSec: 0.010,
        seed: 42
    )
    if let data = json.data(using: .utf8),
       let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let debug = root["debug"] as? [String: Any],
       let windows = debug["windows"] as? [[String: Any]],
       let notes = root["notes"] as? [[String: Any]] {
        debugLog("Debug windows (first 10):")
        for window in windows.prefix(10) {
            debugLog(String(describing: window))
        }
        debugLog("First 30 notes:")
        for note in notes.prefix(30) {
            debugLog(String(describing: note))
        }
    } else {
        debugLog(json)
    }
}

private func settingsForDifficulty(_ difficulty: Difficulty) -> DifficultySettings {
    switch difficulty {
    case .easy:
        return DifficultySettings(
            avgNPS: 2.5, peakNPS: 3.2, floorNPS: 1.5,
            allowQuarter: true, allowEighth: true, allowSixteenth: false,
            sixteenthAccentsOnly: false, burstMaxBeats16: 0,
            chordChance: 0.02, repeatLaneMax: 2, minGapMsPerLane: 90,
            weights: (single: 0.70, alt: 0.25, sweep: 0.05, anchor: 0.0),
            allowExtremeBreath: false
        )
    case .medium:
        return DifficultySettings(
            avgNPS: 4.3, peakNPS: 5.2, floorNPS: 2.8,
            allowQuarter: false, allowEighth: true, allowSixteenth: true,
            sixteenthAccentsOnly: true, burstMaxBeats16: 1,
            chordChance: 0.05, repeatLaneMax: 2, minGapMsPerLane: 70,
            weights: (single: 0.40, alt: 0.40, sweep: 0.15, anchor: 0.05),
            allowExtremeBreath: false
        )
    case .hard:
        return DifficultySettings(
            avgNPS: 7.0, peakNPS: 8.5, floorNPS: 4.5,
            allowQuarter: false, allowEighth: true, allowSixteenth: true,
            sixteenthAccentsOnly: false, burstMaxBeats16: 2,
            chordChance: 0.08, repeatLaneMax: 3, minGapMsPerLane: 55,
            weights: (single: 0.20, alt: 0.45, sweep: 0.20, anchor: 0.15),
            allowExtremeBreath: false
        )
    case .extreme:
        return DifficultySettings(
            avgNPS: 10.0, peakNPS: 12.2, floorNPS: 6.5,
            allowQuarter: false, allowEighth: true, allowSixteenth: true,
            sixteenthAccentsOnly: false, burstMaxBeats16: 4,
            chordChance: 0.12, repeatLaneMax: 4, minGapMsPerLane: 45,
            weights: (single: 0.10, alt: 0.45, sweep: 0.20, anchor: 0.25),
            allowExtremeBreath: true
        )
    }
}

private func npsMultiplier(at time: Double) -> Double {
    switch time {
    case 0..<36:
        return 0.70
    case 36..<84:
        return 1.00
    case 84..<108:
        return 1.20
    case 108..<144:
        return 0.85
    case 144..<192:
        return 1.15
    default:
        return 1.00
    }
}

private func isPeakSegment(_ time: Double) -> Bool {
    (time >= 84 && time < 108) || (time >= 144 && time < 192)
}

private func chooseSubdivisionMode(
    targetNPS: Double,
    difficulty: Difficulty,
    settings: DifficultySettings,
    rng: inout LCG
) -> SubdivisionMode {
    if targetNPS <= 3.2 {
        if settings.allowQuarter && targetNPS < 2.2 {
            return .quarter
        }
        return .eighth
    }
    if targetNPS <= 6.0 {
        if settings.allowSixteenth && settings.sixteenthAccentsOnly {
            return .eighthWithAccents
        }
        return .eighth
    }
    if difficulty == .extreme && settings.allowExtremeBreath {
        let roll = rng.nextDouble()
        if roll < 0.15 {
            return .eighth
        }
        return .sixteenthWithBreath
    }
    return settings.allowSixteenth ? .sixteenth : .eighth
}

private func buildSlots(
    mode: SubdivisionMode,
    wStart: Double,
    wEnd: Double,
    quarter: Double,
    eighth: Double,
    sixteenth: Double
) -> [Double] {
    func slots(step: Double) -> [Double] {
        guard step > 0 else { return [] }
        var result: [Double] = []
        var t = ceil(wStart / step) * step
        while t < wEnd - 0.0001 {
            result.append(roundTo3(t))
            t += step
        }
        return result
    }

    switch mode {
    case .quarter:
        return slots(step: quarter)
    case .eighth:
        return slots(step: eighth)
    case .sixteenth:
        return slots(step: sixteenth)
    case .eighthWithAccents:
        let base = slots(step: eighth)
        let accents = slots(step: sixteenth).filter { t in
            let mod = (t / eighth).rounded(.down)
            let baseT = mod * eighth
            return abs(t - baseT) > 0.0001
        }
        return base + accents
    case .sixteenthWithBreath:
        return slots(step: sixteenth)
    }
}

private func selectSlots(
    candidateSlots: [Double],
    count: Int,
    peakSegment: Bool,
    rng: inout LCG
) -> [Double] {
    guard count > 0, !candidateSlots.isEmpty else { return [] }
    if count >= candidateSlots.count {
        return candidateSlots.sorted()
    }

    var selected: [Double] = []
    let sorted = candidateSlots.sorted()
    if peakSegment {
        var pool = sorted
        for _ in 0..<count {
            let idx = rng.nextInt(pool.count)
            selected.append(pool.remove(at: idx))
        }
        return selected.sorted()
    }

    let stride = max(1, sorted.count / count)
    for i in 0..<count {
        let base = i * stride
        let jitterMax = max(1, stride / 2)
        var idx = base + rng.nextInt(jitterMax)
        if idx >= sorted.count { idx = sorted.count - 1 }
        let value = sorted[idx]
        if !selected.contains(value) {
            selected.append(value)
        }
    }

    if selected.count < count {
        var pool = sorted.filter { !selected.contains($0) }
        while selected.count < count, !pool.isEmpty {
            let idx = rng.nextInt(pool.count)
            selected.append(pool.remove(at: idx))
        }
    }
    return selected.sorted()
}

private func createNotesForSlot(
    time: Double,
    lastLane: Int,
    repeatCount: Int,
    lastLaneTime: [Double],
    sweepIndex: Int,
    sweepDirection: Int,
    settings: DifficultySettings,
    rng: inout LCG
) -> (notes: [BeatNote]?, state: (sweepIndex: Int, sweepDirection: Int)) {
    let jump = rng.nextDouble() < settings.chordChance
    let pattern = pickPattern(settings: settings, rng: &rng)
    var lane = chooseLane(
        pattern: pattern,
        time: time,
        lastLane: lastLane,
        repeatCount: repeatCount,
        lastLaneTime: lastLaneTime,
        sweepIndex: sweepIndex,
        sweepDirection: sweepDirection,
        settings: settings,
        rng: &rng
    )

    var newSweepIndex = sweepIndex
    var newSweepDirection = sweepDirection

    if pattern == .sweep {
        let next = sweepNext(index: sweepIndex, direction: sweepDirection)
        newSweepIndex = next.index
        newSweepDirection = next.direction
        lane = next.lane
    }

    guard let mainLane = lane else {
        return (nil, (newSweepIndex, newSweepDirection))
    }

    if jump {
        let secondaryLane = chooseSecondaryLane(
            primary: mainLane,
            time: time,
            lastLaneTime: lastLaneTime,
            settings: settings,
            rng: &rng
        )
        if let secondaryLane {
            return ([
                BeatNote(t: time, lane: mainLane, type: "tap"),
                BeatNote(t: time, lane: secondaryLane, type: "tap")
            ], (newSweepIndex, newSweepDirection))
        }
    }
    return ([BeatNote(t: time, lane: mainLane, type: "tap")], (newSweepIndex, newSweepDirection))
}

private enum PatternType {
    case single
    case alt
    case sweep
    case anchor
}

private func pickPattern(settings: DifficultySettings, rng: inout LCG) -> PatternType {
    let total = settings.weights.single + settings.weights.alt + settings.weights.sweep + settings.weights.anchor
    let roll = rng.nextDouble() * total
    if roll < settings.weights.single { return .single }
    if roll < settings.weights.single + settings.weights.alt { return .alt }
    if roll < settings.weights.single + settings.weights.alt + settings.weights.sweep { return .sweep }
    return .anchor
}

private func chooseLane(
    pattern: PatternType,
    time: Double,
    lastLane: Int,
    repeatCount: Int,
    lastLaneTime: [Double],
    sweepIndex: Int,
    sweepDirection: Int,
    settings: DifficultySettings,
    rng: inout LCG
) -> Int? {
    let attempts = 10
    for _ in 0..<attempts {
        let lane: Int
        switch pattern {
        case .single:
            lane = rng.nextInt(4)
        case .alt:
            lane = alternateLane(from: lastLane, rng: &rng)
        case .sweep:
            let next = sweepNext(index: sweepIndex, direction: sweepDirection)
            lane = next.lane
        case .anchor:
            lane = lastLane
        }

        if repeatCount >= settings.repeatLaneMax && lane == lastLane {
            continue
        }
        if time - lastLaneTime[lane] < settings.minGapMsPerLane / 1000.0 {
            continue
        }
        return lane
    }
    return nil
}

private func alternateLane(from lane: Int, rng: inout LCG) -> Int {
    let pairs: [[Int]] = [
        [0, 1], [1, 2], [2, 3],
        [0, 2], [1, 3], [0, 3]
    ]
    let pair = pairs[rng.nextInt(pairs.count)]
    if pair[0] == lane { return pair[1] }
    if pair[1] == lane { return pair[0] }
    return pair[rng.nextInt(2)]
}

private func sweepNext(index: Int, direction: Int) -> (lane: Int, index: Int, direction: Int) {
    let lane = max(0, min(3, index))
    var nextIndex = index + direction
    var nextDirection = direction
    if nextIndex > 3 {
        nextIndex = 2
        nextDirection = -1
    } else if nextIndex < 0 {
        nextIndex = 1
        nextDirection = 1
    }
    return (lane, nextIndex, nextDirection)
}

private func chooseSecondaryLane(
    primary: Int,
    time: Double,
    lastLaneTime: [Double],
    settings: DifficultySettings,
    rng: inout LCG
) -> Int? {
    var lanes = [0, 1, 2, 3].filter { $0 != primary }
    lanes.shuffle(using: &rng)
    for lane in lanes {
        if time - lastLaneTime[lane] >= settings.minGapMsPerLane / 1000.0 {
            return lane
        }
    }
    return nil
}

private func enforceWindowNPS(
    windowNotes: [BeatNote],
    targetNPS: Double,
    windowSec: Double,
    wStart: Double,
    wEnd: Double,
    candidateSlots: [Double],
    settings: DifficultySettings,
    lastLaneTime: inout [Double],
    lastLane: inout Int,
    repeatCount: inout Int,
    sweepIndex: inout Int,
    sweepDirection: inout Int,
    rng: inout LCG
) -> [BeatNote] {
    var notes = windowNotes
    let desired = targetNPS * windowSec
    let upper = desired + 0.5
    let lower = desired - 0.5

    while Double(notes.count) > upper, !notes.isEmpty {
        if let idx = removalIndex(notes: notes) {
            notes.remove(at: idx)
        } else {
            notes.removeLast()
        }
    }

    let usedSlots = Set(notes.map { $0.t })
    var slotPool = candidateSlots.filter { $0 >= wStart && $0 < wEnd && !usedSlots.contains($0) }
    while Double(notes.count) < lower, !slotPool.isEmpty {
        let slotIndex = rng.nextInt(slotPool.count)
        let slot = slotPool.remove(at: slotIndex)
        let (created, state) = createNotesForSlot(
            time: slot,
            lastLane: lastLane,
            repeatCount: repeatCount,
            lastLaneTime: lastLaneTime,
            sweepIndex: sweepIndex,
            sweepDirection: sweepDirection,
            settings: settings,
            rng: &rng
        )
        if let created = created {
            notes.append(contentsOf: created)
            for note in created {
                lastLaneTime[note.lane] = note.t
                if note.lane == lastLane {
                    repeatCount += 1
                } else {
                    lastLane = note.lane
                    repeatCount = 1
                }
            }
        }
        sweepIndex = state.sweepIndex
        sweepDirection = state.sweepDirection
    }

    return notes
}

private func removalIndex(notes: [BeatNote]) -> Int? {
    let timeCounts = notes.reduce(into: [Double: Int]()) { acc, note in
        acc[note.t, default: 0] += 1
    }
    for (idx, note) in notes.enumerated() {
        if isSixteenthAccent(note.t) {
            return idx
        }
        if (timeCounts[note.t] ?? 0) > 1 {
            return idx
        }
    }
    return nil
}

private func isSixteenthAccent(_ time: Double) -> Bool {
    let beat = 60.0 / 138.0
    let eighth = beat / 2.0
    let mod = time.truncatingRemainder(dividingBy: eighth)
    return mod > 0.0001
}

private func dedupeNotes(_ notes: [BeatNote]) -> [BeatNote] {
    var seen = Set<BeatNote>()
    var result: [BeatNote] = []
    for note in notes {
        if seen.contains(note) { continue }
        seen.insert(note)
        result.append(note)
    }
    return result
}

private func buildJSON(
    bpm: Double,
    durationSec: Double,
    offsetSec: Double,
    difficulty: String,
    notes: [BeatNote],
    windowSec: Double,
    debug: [DebugWindow]
) -> String {
    let notesArray: [[String: Any]] = notes.map {
        ["t": $0.t, "lane": $0.lane, "type": $0.type]
    }
    let windowsArray: [[String: Any]] = debug.map {
        [
            "start": roundTo3($0.start),
            "end": roundTo3($0.end),
            "targetNPS": $0.targetNPS,
            "actualNPS": $0.actualNPS,
            "notes": $0.notes
        ]
    }

    let root: [String: Any] = [
        "version": 1,
        "bpm": bpm,
        "durationSec": durationSec,
        "offsetSec": offsetSec,
        "difficulty": difficulty,
        "notes": notesArray,
        "debug": [
            "windowSec": windowSec,
            "windows": windowsArray
        ]
    ]

    if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
       let json = String(data: data, encoding: .utf8) {
        return json
    }
    return "{}"
}

private func clamp(_ value: Double, _ minVal: Double, _ maxVal: Double) -> Double {
    max(minVal, min(maxVal, value))
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

private func roundTo3(_ value: Double) -> Double {
    (value * 1000.0).rounded() / 1000.0
}

private extension Array {
    mutating func shuffle(using rng: inout LCG) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            if i != j { swapAt(i, j) }
        }
    }
}
