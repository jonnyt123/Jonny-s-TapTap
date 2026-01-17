import Foundation
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Beatmap Models (Int64 ms timestamps)

enum BeatNoteType: String, Codable { case tap }

struct BeatmapSong: Codable {
    let filename: String
    let durationSec: Double
    let sha256: String?
}

struct BeatmapNote: Codable, Equatable {
    let tMs: Int64
    let lane: Int
    let type: BeatNoteType
    let durMs: Int64?
}

struct Beatmap: Codable {
    let version: Int
    let createdAt: Date
    let lanes: Int
    let offsetMs: Int64
    let song: BeatmapSong
    var notes: [BeatmapNote]
}

// MARK: - Beatmap Store (ISO8601 Date)

enum BeatmapStore {
    static func encoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    static func documentsURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    static func save(_ beatmap: Beatmap, to url: URL) throws {
        let data = try encoder().encode(beatmap)
        try data.write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> Beatmap {
        let data = try Data(contentsOf: url)
        return try decoder().decode(Beatmap.self, from: data)
    }
}

// MARK: - Safer MP3 Import (copy into app container)

enum SongImport {
    static func copyIntoDocuments(from pickedURL: URL) throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(pickedURL.lastPathComponent)

        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }

        try fm.copyItem(at: pickedURL, to: dest)
        return dest
    }
}

// MARK: - Sample-accurate Editor Audio Engine (ms Int64)

final class EditorAudioEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44100

    private var startSampleTime: AVAudioFramePosition?
    private var accumulatedPauseMs: Int64 = 0
    private var isPaused: Bool = false

    var durationSec: Double {
        guard let f = audioFile else { return 0 }
        return Double(f.length) / f.processingFormat.sampleRate
    }

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    func load(url: URL) throws {
        try configureSession()
        let file = try AVAudioFile(forReading: url)
        audioFile = file
        sampleRate = file.processingFormat.sampleRate

        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
    }

    func playFromStart() throws {
        try seek(toMs: 0)
        try play()
    }

    func play() throws {
        guard let file = audioFile else { return }
        if !engine.isRunning { try engine.start() }

        if !player.isPlaying {
            if isPaused {
                isPaused = false
                startSampleTime = nil
            } else {
                accumulatedPauseMs = 0
                startSampleTime = nil
                player.stop()
                player.scheduleFile(file, at: nil, completionHandler: nil)
            }
            player.play()
        }
    }

    func pause() {
        guard player.isPlaying else { return }
        accumulatedPauseMs = currentRawSongMs()
        player.pause()
        isPaused = true
        startSampleTime = nil
    }

    func stop() {
        player.stop()
        engine.stop()
        accumulatedPauseMs = 0
        startSampleTime = nil
        isPaused = false
    }

    func seek(toMs ms: Int64) throws {
        guard let file = audioFile else { return }

        let clampedMs = max(0, min(ms, Int64((Double(file.length) / sampleRate) * 1000.0)))
        let frame = AVAudioFramePosition((Double(clampedMs) / 1000.0) * sampleRate)

        player.stop()
        startSampleTime = nil
        accumulatedPauseMs = clampedMs
        isPaused = false

        file.framePosition = frame

        if !engine.isRunning { try engine.start() }
        player.scheduleFile(file, at: nil, completionHandler: nil)
    }

    func currentRawSongMs() -> Int64 {
        guard
            let nodeTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: nodeTime)
        else {
            return accumulatedPauseMs
        }

        if startSampleTime == nil {
            startSampleTime = playerTime.sampleTime
            return accumulatedPauseMs
        }

        guard let start = startSampleTime else { return accumulatedPauseMs }
        let deltaSamples = Double(playerTime.sampleTime - start)
        let deltaMs = Int64(((deltaSamples / sampleRate) * 1000.0).rounded())
        return accumulatedPauseMs + max(0, deltaMs)
    }
}

// MARK: - Beatmap Recording helper

final class BeatmapRecorder: ObservableObject {
    @Published private(set) var notes: [BeatmapNote] = []
    private(set) var lanes: Int

    init(lanes: Int) {
        self.lanes = lanes
    }

    func setLanes(_ lanes: Int) {
        self.lanes = lanes
        notes.removeAll()
    }

    func recordTap(tMs: Int64, lane: Int) {
        guard (0..<lanes).contains(lane) else { return }
        notes.append(BeatmapNote(tMs: max(0, tMs), lane: lane, type: .tap, durMs: nil))
    }

    func undo() {
        _ = notes.popLast()
    }

    func sortedNotes() -> [BeatmapNote] {
        notes.sorted { a, b in a.tMs == b.tMs ? a.lane < b.lane : a.tMs < b.tMs }
    }
}

enum BeatmapAdapter {
    static func toNotes(_ beatmap: Beatmap) -> [Note] {
        beatmap.notes.map { note in
            let timeSec = Double(note.tMs + beatmap.offsetMs) / 1000.0
            return Note(time: timeSec, lane: note.lane, type: .tap, duration: nil)
        }
        .sorted { $0.time < $1.time }
    }
}
