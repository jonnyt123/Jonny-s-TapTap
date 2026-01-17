import Foundation
import CoreGraphics

enum NoteType: String, Codable {
    case tap = "tap"
    case shake = "shake"
    case hold = "hold"
}

enum Difficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case extreme = "Extreme"
    
    var noteSpeedMultiplier: CGFloat {
        switch self {
        case .easy: return 0.7
        case .medium: return 1.0
        case .hard: return 1.3
        case .extreme: return 1.6
        }
    }
    
    var noteDensityDivisor: Int {
        switch self {
        case .easy: return 5
        case .medium: return 3
        case .hard: return 2
        case .extreme: return 1
        }
    }
}

struct Note: Codable, Identifiable {
    let id: String
    let time: Double
    let lane: Int
    let type: NoteType
    let duration: Double?

    init(id: String = UUID().uuidString, time: Double, lane: Int, type: NoteType = .tap, duration: Double? = nil) {
        self.id = id
        self.time = time
        self.lane = lane
        self.type = type
        self.duration = duration
    }
    
    enum CodingKeys: String, CodingKey {
        case id, time, lane, type, duration
    }
}

struct Chart: Codable {
    let version: Int?
    let difficulty: Difficulty?
    let songName: String
    let bpm: Double
    let offset: Double
    let lanes: Int
    let notes: [Note]
}

enum ChartLoader {
    struct LoadResult {
        let chart: Chart
        let usedDifficulty: Difficulty
        let requestedDifficulty: Difficulty
        let fileName: String
        let wasFallback: Bool
    }

    static func loadChart(for song: SongMetadata, difficulty: Difficulty) -> LoadResult {
        // Try requested, then fallback order (medium -> easy -> hard -> extreme -> placeholder)
        let ordered = fallbackOrder(requested: difficulty)
        for diff in ordered {
            let fileName = song.chartFiles.name(for: diff)
            if let chart = decodeChart(fileName: fileName) {
                return LoadResult(chart: chart, usedDifficulty: diff, requestedDifficulty: difficulty, fileName: fileName, wasFallback: diff != difficulty)
            }
        }
        // Ultimate fallback
        return LoadResult(chart: placeholderChart(), usedDifficulty: difficulty, requestedDifficulty: difficulty, fileName: "placeholder", wasFallback: true)
    }

    static func availability(for song: SongMetadata) -> Set<Difficulty> {
        var available: Set<Difficulty> = []
        for diff in Difficulty.allCases {
            let name = song.chartFiles.name(for: diff)
            if Bundle.main.url(forResource: name, withExtension: "json") != nil {
                available.insert(diff)
            }
        }
        return available
    }

    private static func decodeChart(fileName: String) -> Chart? {
        guard let url = resolveChartURL(fileName: fileName),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(Chart.self, from: data)
    }

    private static func resolveChartURL(fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            return url
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Resources") {
            return url
        }
        guard let resourceRoot = Bundle.main.resourceURL else {
            return nil
        }
        let target = "\(fileName).json"
        let enumerator = FileManager.default.enumerator(at: resourceRoot, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == target {
                return fileURL
            }
        }
        return nil
    }

    private static func fallbackOrder(requested: Difficulty) -> [Difficulty] {
        switch requested {
        case .easy: return [.easy, .medium, .hard, .extreme]
        case .medium: return [.medium, .easy, .hard, .extreme]
        case .hard: return [.hard, .medium, .extreme, .easy]
        case .extreme: return [.extreme, .hard, .medium, .easy]
        }
    }

    private static func densifyExtremeNotes(from notes: [Note], lanes: Int) -> [Note] {
        guard notes.count >= 2 else { return notes }
        let laneCount = max(lanes, 1)
        let sortedNotes = notes.sorted { $0.time < $1.time }
        var extras: [Note] = []

        for index in 0..<(sortedNotes.count - 1) {
            let current = sortedNotes[index]
            let next = sortedNotes[index + 1]
            let gap = next.time - current.time

            // Insert one extra tap in medium gaps, two in very long gaps to raise density.
            if gap >= 0.5 {
                let lane = (current.lane + 1) % laneCount
                extras.append(Note(time: current.time + gap * 0.5, lane: lane, type: .tap))
            }

            if gap >= 1.2 {
                let lane = (current.lane + 2) % laneCount
                extras.append(Note(time: current.time + gap * (2.0 / 3.0), lane: lane, type: .tap))
            }
        }

        let combined = (sortedNotes + extras).sorted { $0.time < $1.time }
        return combined
    }

    private static func placeholderChart() -> Chart {
        Chart(
            version: 1,
            difficulty: nil,
            songName: "Placeholder",
            bpm: 120,
            offset: 0,
            lanes: 3,
            notes: placeholderNotes()
        )
    }

    private static func placeholderNotes() -> [Note] {
        var items: [Note] = []
        let pattern = [0, 1, 2, 1]
        var t: Double = 1.0
        for _ in 0..<24 {
            for lane in pattern {
                items.append(Note(time: t, lane: lane, type: .tap))
                t += 0.4
            }
        }
        return items
    }
}
