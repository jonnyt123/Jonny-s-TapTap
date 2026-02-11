import XCTest
@testable import RhythmTap

/// Unit tests for chart/beatmap JSON parsing (Chart, Note, NoteType, Difficulty).
final class BeatmapParsingTests: XCTestCase {

    func testDecodeMinimalChart() throws {
        let json = """
        {
            "songName": "Test",
            "bpm": 120,
            "offset": 0,
            "lanes": 3,
            "notes": [
                { "id": "n1", "time": 1.0, "lane": 0, "type": "tap" },
                { "id": "n2", "time": 2.0, "lane": 1, "type": "tap" }
            ]
        }
        """
        let data = Data(json.utf8)
        let chart = try JSONDecoder().decode(Chart.self, from: data)
        XCTAssertEqual(chart.songName, "Test")
        XCTAssertEqual(chart.bpm, 120)
        XCTAssertEqual(chart.offset, 0)
        XCTAssertEqual(chart.lanes, 3)
        XCTAssertEqual(chart.notes.count, 2)
        XCTAssertEqual(chart.notes[0].time, 1.0)
        XCTAssertEqual(chart.notes[0].lane, 0)
        XCTAssertEqual(chart.notes[0].type, .tap)
        XCTAssertEqual(chart.notes[1].time, 2.0)
        XCTAssertEqual(chart.notes[1].lane, 1)
    }

    func testDecodeChartWithOptionalFields() throws {
        let json = """
        {
            "version": 2,
            "difficulty": "Medium",
            "songName": "Optional",
            "bpm": 138,
            "offset": 0.01,
            "lanes": 4,
            "notes": [
                { "id": "h1", "time": 0.5, "lane": 2, "type": "hold", "duration": 0.3 }
            ]
        }
        """
        let data = Data(json.utf8)
        let chart = try JSONDecoder().decode(Chart.self, from: data)
        XCTAssertEqual(chart.version, 2)
        XCTAssertEqual(chart.difficulty, .medium)
        XCTAssertEqual(chart.songName, "Optional")
        XCTAssertEqual(chart.lanes, 4)
        XCTAssertEqual(chart.notes.count, 1)
        XCTAssertEqual(chart.notes[0].type, .hold)
        XCTAssertEqual(chart.notes[0].duration, 0.3)
    }

    func testDecodeNoteTypes() throws {
        let json = """
        {
            "songName": "Types",
            "bpm": 100,
            "offset": 0,
            "lanes": 3,
            "notes": [
                { "id": "t1", "time": 0, "lane": 0, "type": "tap" },
                { "id": "s1", "time": 1, "lane": 0, "type": "shake" },
                { "id": "h1", "time": 2, "lane": 0, "type": "hold", "duration": 0.5 }
            ]
        }
        """
        let data = Data(json.utf8)
        let chart = try JSONDecoder().decode(Chart.self, from: data)
        XCTAssertEqual(chart.notes[0].type, .tap)
        XCTAssertEqual(chart.notes[1].type, .shake)
        XCTAssertEqual(chart.notes[2].type, .hold)
    }

    func testDecodeDifficultyValues() throws {
        let json = """
        {
            "songName": "D",
            "bpm": 100,
            "offset": 0,
            "lanes": 3,
            "notes": [],
            "difficulty": "Extreme"
        }
        """
        let data = Data(json.utf8)
        let chart = try JSONDecoder().decode(Chart.self, from: data)
        XCTAssertEqual(chart.difficulty, .extreme)
    }

    func testChartLoaderPlaceholderFallback() {
        // ChartLoader.loadChart always returns a valid result (placeholder if no file).
        let song = SongMetadata.default
        let result = ChartLoader.loadChart(for: song, difficulty: .medium)
        XCTAssertFalse(result.chart.notes.isEmpty)
        XCTAssertGreaterThanOrEqual(result.chart.lanes, 1)
        XCTAssertGreaterThan(result.chart.bpm, 0)
    }

    func testChartAvailabilityNonEmptyForLibrary() {
        // At least default song should have some difficulty available from bundle.
        let song = SongMetadata.default
        let available = ChartLoader.availability(for: song)
        XCTAssertFalse(available.isEmpty, "Default song should have at least one difficulty")
    }
}
