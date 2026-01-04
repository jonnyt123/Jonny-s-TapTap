import SwiftUI

struct SongMetadata: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let audioName: String
    let audioExtension: String
    let chartName: String
    let lanes: Int
    let bpm: Double
    let primaryColors: [Color]
    let accent: Color
}

extension SongMetadata {
    static let library: [SongMetadata] = [
        SongMetadata(
            id: "track3",
            title: "Hallelujah",
            artist: "Jonny Thompson",
            audioName: "track 3",
            audioExtension: "wav",
            chartName: "chart",
            lanes: 3,
            bpm: 110,
            primaryColors: [
                Color(red: 0.86, green: 0.36, blue: 1.0),
                Color(red: 0.18, green: 0.31, blue: 0.82)
            ],
            accent: .cyan
        ),
        SongMetadata(
            id: "crazy-train",
            title: "Crazy Train",
            artist: "Ozzy Osbourne",
            audioName: "crazy_train",
            audioExtension: "mp3",
            chartName: "crazy_train",
            lanes: 4,
            bpm: 138.0,
            primaryColors: [
                Color(red: 0.85, green: 0.24, blue: 0.21),
                Color(red: 0.08, green: 0.08, blue: 0.15)
            ],
            accent: Color.orange
        ),
            SongMetadata(
                id: "i-will-not-bow",
                title: "I Will Not Bow",
                artist: "Breaking Benjamin",
                audioName: "i_will_not_bow",
                audioExtension: "mp3",
                chartName: "i_will_not_bow",
                lanes: 4,
                bpm: 92,
                primaryColors: [
                    Color(red: 0.10, green: 0.14, blue: 0.20),
                    Color(red: 0.45, green: 0.05, blue: 0.08)
                ],
                accent: Color.red
            ),
        SongMetadata(
            id: "day-n-nite",
            title: "Day 'N' Nite",
            artist: "Kid Cudi",
            audioName: "day_n_nite",
            audioExtension: "mp3",
            chartName: "day_n_nite",
            lanes: 4,
            bpm: 139.67,
            primaryColors: [
                Color(red: 0.10, green: 0.22, blue: 0.36),
                Color(red: 0.00, green: 0.50, blue: 0.55)
            ],
            accent: Color.mint
        )
    ]
    
    static let `default`: SongMetadata = library.first ?? SongMetadata(
        id: "fallback",
        title: "Unknown",
        artist: "",
        audioName: "track 3",
        audioExtension: "wav",
        chartName: "chart",
        lanes: 3,
        bpm: 120,
        primaryColors: [.purple, .blue],
        accent: .cyan
    )
}
