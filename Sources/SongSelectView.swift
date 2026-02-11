import SwiftUI
import SpriteKit

struct SongSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSong: SongMetadata
    @Binding var selectedDifficulty: Difficulty
    var songs: [SongMetadata]
    var availableDifficulties: Set<Difficulty>
    var unlockedSongIDs: Set<String>
    @State private var scene = SongSelectScene(size: .zero)
    @State private var showDifficultyMenu = false
    @State private var showUserBeatmaps = false
    @State private var currentSongDifficulties: Set<Difficulty> = []
    var onPlayRequested: (() -> Void)?
    private let userBeatmapSelectorID = "user_beatmap_selector"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .focusable(false)
                    .onAppear {
                        scene.scaleMode = .resizeFill
                        scene.size = geo.size
                        scene.songs = songs
                        scene.currentIndex = songs.firstIndex(where: { $0.id == selectedSong.id }) ?? 0
                        scene.onCurrentSongChanged = { song in
                            selectedSong = song
                            currentSongDifficulties = availableDifficulties(for: song)
                        }
                        scene.isSongUnlocked = { song in
                            if song.id == userBeatmapSelectorID {
                                return true
                            }
                            if SongMetadata.library.contains(where: { $0.id == song.id }) {
                                return unlockedSongIDs.contains(song.id)
                            }
                            return true
                        }
                        scene.onBack = { dismiss() }
                    scene.onPlayRequested = { song in
                            if song.id == userBeatmapSelectorID {
                                showUserBeatmaps = true
                                return
                            }
                            let songDifficulties = availableDifficulties(for: song)
                            guard !songDifficulties.isEmpty else { return }
                            if !songDifficulties.contains(selectedDifficulty) {
                                selectedDifficulty = songDifficulties.first ?? selectedDifficulty
                            }
                            selectedSong = song
                            currentSongDifficulties = songDifficulties
                            showDifficultyMenu = true
                        }
                        currentSongDifficulties = availableDifficulties(for: selectedSong)
                    }
                .onChange(of: geo.size) { _, newSize in
                    scene.size = newSize
                    }

                if showDifficultyMenu {
                    difficultyMenu
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .sheet(isPresented: $showUserBeatmaps) {
            UserBeatmapPickerView { beatmap, url in
                let song = userSongMetadata(from: beatmap, url: url)
                selectedSong = song
                showUserBeatmaps = false
                onPlayRequested?()
            }
        }
        .onDisappear { }
    }

    private var difficultyMenu: some View {
        ZStack {
            RTModalScrim {
                withAnimation(RTTheme.Animation.quickEaseOut) {
                    showDifficultyMenu = false
                }
            }

            VStack(spacing: RTTheme.Spacing.section) {
                VStack(spacing: RTTheme.Spacing.sm) {
                    Text("CHOOSE DIFFICULTY")
                        .font(RTTheme.Fonts.headline(18))
                        .foregroundColor(RTTheme.Colors.textPrimary)
                    Text(selectedSong.title.uppercased())
                        .font(RTTheme.Fonts.caption(12))
                        .foregroundColor(RTTheme.Colors.textMuted)
                }

                HStack(spacing: RTTheme.Spacing.medium) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        let isAvailable = currentSongDifficulties.contains(difficulty)
                        Button(action: {
                            guard isAvailable else { return }
                            RTHaptics.impact()
                            selectedDifficulty = difficulty
                        }) {
                            VStack(spacing: RTTheme.Spacing.xs) {
                                Text(difficulty.rawValue.prefix(1))
                                    .font(RTTheme.Fonts.headline(18))
                                Text(difficulty.rawValue)
                                    .font(RTTheme.Fonts.label(10))
                            }
                            .foregroundColor(isAvailable ? RTTheme.Colors.textPrimary : RTTheme.Colors.textDisabled)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RTTheme.Spacing.medium)
                            .background(
                                isAvailable
                                    ? (selectedDifficulty == difficulty ? RTTheme.Colors.selectedRed : RTTheme.Colors.surfaceMuted)
                                    : RTTheme.Colors.surfaceSubtle
                            )
                            .cornerRadius(RTTheme.Radius.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                                    .stroke(selectedDifficulty == difficulty ? RTTheme.Colors.selectedStroke : Color.clear, lineWidth: 2)
                            )
                        }
                        .disabled(!isAvailable)
                    }
                }

                RTPrimaryButton(title: "CONTINUE", icon: "play.fill") {
                    RTHaptics.impact()
                    withAnimation(RTTheme.Animation.quickEaseOut) {
                        showDifficultyMenu = false
                    }
                    onPlayRequested?()
                }

                RTGhostButton(title: "BACK") {
                    withAnimation(RTTheme.Animation.quickEaseOut) {
                        showDifficultyMenu = false
                    }
                }
            }
            .padding(RTTheme.Spacing.section)
            .frame(maxWidth: 360)
            .background(
                LinearGradient(
                    colors: [RTTheme.Colors.backgroundCardStart, RTTheme.Colors.backgroundCardEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(RTTheme.Radius.modal)
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.modal)
                    .stroke(RTTheme.Colors.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: RTTheme.Shadow.modal().color, radius: RTTheme.Shadow.modal().radius, y: RTTheme.Shadow.modal().y)
            .padding(.horizontal, RTTheme.Spacing.screen)
        }
    }

    private func availableDifficulties(for song: SongMetadata) -> Set<Difficulty> {
        ChartLoader.availability(for: song)
    }
}

private func userSongMetadata(from beatmap: Beatmap, url: URL) -> SongMetadata {
    let filename = beatmap.song.filename
    let ext = URL(fileURLWithPath: filename).pathExtension.isEmpty
        ? url.pathExtension
        : URL(fileURLWithPath: filename).pathExtension
    let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    return SongMetadata(
        id: "user_beatmap",
        title: baseName,
        artist: "User Beatmap",
        audioName: baseName,
        audioExtension: ext.isEmpty ? "mp3" : ext,
        chartFiles: ChartFiles(same: "user_beatmap"),
        lanes: beatmap.lanes,
        bpm: 120,
        primaryColors: [
            Color(red: 0.12, green: 0.12, blue: 0.14),
            Color(red: 0.45, green: 0.10, blue: 0.20)
        ],
        accent: .red
    )
}
