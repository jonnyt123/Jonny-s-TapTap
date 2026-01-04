import Foundation

enum NoteType: String, Codable {
    case tap = "tap"
    case shake = "shake"
    case hold = "hold"
}

enum Difficulty: String, CaseIterable {
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
    let id: UUID
    let time: Double
    let lane: Int
    let type: NoteType
    let duration: Double?

    init(id: UUID = UUID(), time: Double, lane: Int, type: NoteType = .tap, duration: Double? = nil) {
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
    let songName: String
    let bpm: Double
    let offset: Double
    let lanes: Int
    let notes: [Note]
}

enum ChartLoader {
    static func loadChart(named chartName: String = "chart", difficulty: Difficulty = .medium) -> Chart {
        guard let url = Bundle.main.url(forResource: chartName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let chart = try? JSONDecoder().decode(Chart.self, from: data) else {
            return Chart(
                songName: "Placeholder",
                bpm: 120,
                offset: 0,
                lanes: 3,
                notes: Self.placeholderNotes()
            )
        }
        
        // Filter notes based on difficulty density
        let divisor = difficulty.noteDensityDivisor
        let filteredNotes = chart.notes.enumerated().filter { index, _ in
            index % divisor == 0
        }.map { $0.element }
        let finalNotes: [Note]
        if difficulty == .extreme {
            finalNotes = densifyExtremeNotes(from: filteredNotes, lanes: chart.lanes)
        } else {
            finalNotes = filteredNotes
        }
        
        return Chart(
            songName: chart.songName,
            bpm: chart.bpm,
            offset: chart.offset,
            lanes: chart.lanes,
            notes: finalNotes
        )
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
