import SwiftUI

struct ChartFiles: Equatable {
    let easy: String
    let medium: String
    let hard: String
    let extreme: String
    
    init(same base: String) {
        self.easy = base
        self.medium = base
        self.hard = base
        self.extreme = base
    }
    
    init(easy: String, medium: String, hard: String, extreme: String) {
        self.easy = easy
        self.medium = medium
        self.hard = hard
        self.extreme = extreme
    }
    
    func name(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return easy
        case .medium: return medium
        case .hard: return hard
        case .extreme: return extreme
        }
    }
}

struct SongMetadata: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let audioName: String
    let audioExtension: String
    let chartFiles: ChartFiles
    let lanes: Int
    let bpm: Double
    let primaryColors: [Color]
    let accent: Color
}

extension SongMetadata {
    static let library: [SongMetadata] = [
        SongMetadata(
            id: "hallelujah",
            title: "Hallelujah",
            artist: "Jonny Thompson",
            audioName: "hallelujah",
            audioExtension: "wav",
            chartFiles: ChartFiles(
                easy: "hallelujah_easy",
                medium: "hallelujah_medium",
                hard: "hallelujah_hard",
                extreme: "hallelujah_extreme"
            ),
            lanes: 3,
            bpm: 110,
            primaryColors: [
                Color(red: 0.86, green: 0.36, blue: 1.0),
                Color(red: 0.18, green: 0.31, blue: 0.82)
            ],
            accent: .cyan
        ),
        SongMetadata(
            id: "test_song",
            title: "Test Song",
            artist: "QA Band",
            audioName: "hallelujah", // reuse bundled audio
            audioExtension: "wav",
            chartFiles: ChartFiles(
                easy: "test_song_easy",
                medium: "test_song_medium",
                hard: "test_song_hard",
                extreme: "test_song_extreme"
            ),
            lanes: 4,
            bpm: 120,
            primaryColors: [
                Color(red: 0.2, green: 0.8, blue: 1.0),
                Color(red: 1.0, green: 0.4, blue: 0.6)
            ],
            accent: .orange
        ),
        SongMetadata(
            id: "crazy_train",
            title: "Crazy Train",
            artist: "Ozzy Osbourne",
            audioName: "crazy_train",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "crazy_train"),
            lanes: 4,
            bpm: 138,
            primaryColors: [
                Color(red: 0.85, green: 0.24, blue: 0.21),
                Color(red: 0.08, green: 0.08, blue: 0.15)
            ],
            accent: .orange
        ),
        SongMetadata(
            id: "i_will_not_bow",
            title: "I Will Not Bow",
            artist: "Breaking Benjamin",
            audioName: "i_will_not_bow",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "i_will_not_bow"),
            lanes: 4,
            bpm: 92,
            primaryColors: [
                Color(red: 0.10, green: 0.14, blue: 0.20),
                Color(red: 0.45, green: 0.05, blue: 0.08)
            ],
            accent: .red
        ),
        SongMetadata(
            id: "day_n_nite",
            title: "Day 'N' Nite",
            artist: "Kid Cudi",
            audioName: "day_n_nite",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "day_n_nite"),
            lanes: 4,
            bpm: 139.67,
            primaryColors: [
                Color(red: 0.10, green: 0.22, blue: 0.36),
                Color(red: 0.00, green: 0.50, blue: 0.55)
            ],
            accent: .mint
        ),
        SongMetadata(
            id: "blink182_see_you",
            title: "See You",
            artist: "blink-182",
            audioName: "blink182_see_you",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "blink182_see_you"),
            lanes: 3,
            bpm: 100,
            primaryColors: [
                Color(red: 0.8, green: 0.2, blue: 0.8),
                Color(red: 0.0, green: 0.8, blue: 0.8)
            ],
            accent: .yellow
        ),
        SongMetadata(
            id: "madchild_chainsaw",
            title: "Chainsaw",
            artist: "Madchild ft. Slaine",
            audioName: "madchild_chainsaw",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "madchild_chainsaw"),
            lanes: 3,
            bpm: 95,
            primaryColors: [
                Color(red: 0.7, green: 0.0, blue: 0.0),
                Color(red: 0.0, green: 0.7, blue: 0.7)
            ],
            accent: .red
        ),
        SongMetadata(
            id: "hippie_sabotage_high",
            title: "High Enough",
            artist: "Hippie Sabotage",
            audioName: "hippie_sabotage_high",
            audioExtension: "m4a",
            chartFiles: ChartFiles(same: "hippie_sabotage_high"),
            lanes: 3,
            bpm: 110,
            primaryColors: [
                Color(red: 1.0, green: 0.5, blue: 0.0),
                Color(red: 0.0, green: 0.5, blue: 1.0)
            ],
            accent: .purple
        ),
        SongMetadata(
            id: "mgk_dont_let_me_go",
            title: "Don't Let Me Go",
            artist: "MGk",
            audioName: "mgk_dont_let_me_go",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "mgk_dont_let_me_go"),
            lanes: 4,
            bpm: 120,
            primaryColors: [
                Color(red: 0.2, green: 0.2, blue: 0.8),
                Color(red: 0.8, green: 0.2, blue: 0.2)
            ],
            accent: .cyan
        ),
        SongMetadata(
            id: "bizzy_banks_fonem",
            title: "On Fonem Grave",
            artist: "Bizzy Banks",
            audioName: "bizzy_banks_fonem",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "bizzy_banks_fonem"),
            lanes: 3,
            bpm: 85,
            primaryColors: [
                Color(red: 0.9, green: 0.7, blue: 0.0),
                Color(red: 0.1, green: 0.1, blue: 0.1)
            ],
            accent: .orange
        ),
    ]
    
    static let `default`: SongMetadata = library.first ?? SongMetadata(
        id: "fallback",
        title: "Unknown",
        artist: "",
        audioName: "track",
        audioExtension: "wav",
        chartFiles: ChartFiles(same: "chart"),
        lanes: 3,
        bpm: 120,
        primaryColors: [.purple, .blue],
        accent: .cyan
    )
}
