import SwiftUI

// MARK: - Song Model

struct Song: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let difficulty: Int  // 1-4, higher = harder
    let isLocked: Bool
    let metadata: SongMetadata

    static func from(_ m: SongMetadata, unlocked: Bool, availableDifficulties: Set<Difficulty>) -> Song {
        let dur = estimatedDuration(for: m)
        let diff = maxDifficultyLevel(availableDifficulties)
        return Song(
            id: m.id,
            title: m.title,
            artist: m.artist,
            duration: dur,
            difficulty: diff,
            isLocked: !unlocked,
            metadata: m
        )
    }

    private static func estimatedDuration(for m: SongMetadata) -> TimeInterval {
        let result = ChartLoader.loadChart(for: m, difficulty: .medium)
        let notes = result.chart.notes
        guard !notes.isEmpty,
              let last = notes.max(by: { ($0.time + ($0.duration ?? 0)) < ($1.time + ($1.duration ?? 0)) }) else {
            return 180
        }
        return last.time + (last.duration ?? 0) + 2
    }

    private static func maxDifficultyLevel(_ diffs: Set<Difficulty>) -> Int {
        if diffs.contains(.extreme) { return 4 }
        if diffs.contains(.hard) { return 3 }
        if diffs.contains(.medium) { return 2 }
        if diffs.contains(.easy) { return 1 }
        return 1
    }
}

// MARK: - SongSelectionViewModel

final class SongSelectionViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var selectedSongID: String?
    @Published var selectedDifficulty: Difficulty = .medium
    @Published var availableDifficulties: Set<Difficulty> = []

    var selectedSong: Song? {
        guard let id = selectedSongID else { return nil }
        return songs.first { $0.id == id }
    }

    func selectSong(_ song: Song) {
        selectedSongID = song.id
        availableDifficulties = ChartLoader.availability(for: song.metadata)
        if !availableDifficulties.contains(selectedDifficulty) {
            selectedDifficulty = availableDifficulties.sorted(by: { $0.rawValue < $1.rawValue }).first ?? .medium
        }
    }

    func selectFirstIfNeeded() {
        if selectedSongID == nil, let first = songs.first, !first.isLocked {
            selectSong(first)
        }
    }

    func buildFromMetadata(
        _ list: [SongMetadata],
        unlockedIDs: Set<String>,
        customBeatmap: Beatmap?,
        userBeatmapSelectorID: String
    ) {
        var items: [Song] = []
        for m in list {
            let unlocked = m.id == userBeatmapSelectorID || m.id == "user_beatmap" || unlockedIDs.contains(m.id)
            let avail = ChartLoader.availability(for: m)
            items.append(Song.from(m, unlocked: unlocked, availableDifficulties: avail))
        }
        songs = items
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
        primaryColors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.45, green: 0.10, blue: 0.20)],
        accent: .red
    )
}

// MARK: - PencilTextStyle Modifier

struct PencilTextStyle: ViewModifier {
    var color: Color = .white
    var shadowRadius: CGFloat = 1
    var shadowOffset: CGSize = CGSize(width: 0.5, height: 0.5)
    var letterSpacing: CGFloat = 0.5

    func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .shadow(
                color: Color.black.opacity(0.6),
                radius: shadowRadius,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
            .tracking(letterSpacing)
    }
}

extension View {
    func pencilTextStyle(
        color: Color = .white,
        shadowRadius: CGFloat = 1,
        shadowOffset: CGSize = CGSize(width: 0.5, height: 0.5),
        letterSpacing: CGFloat = 0.5
    ) -> some View {
        modifier(PencilTextStyle(color: color, shadowRadius: shadowRadius, shadowOffset: shadowOffset, letterSpacing: letterSpacing))
    }
}

// MARK: - SongSelectionSetlistView

struct SongSelectionSetlistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SongSelectionViewModel()
    @Binding var selectedSong: SongMetadata
    @Binding var selectedDifficulty: Difficulty
    var songs: [SongMetadata]
    var unlockedSongIDs: Set<String>
    var customBeatmap: Beatmap?
    var onPlayRequested: (() -> Void)?
    var onUserBeatmapsRequested: (() -> Void)?
    /// When set, the view selects this song and scrolls to it after building the list.
    var preselectedSongID: String? = nil

    private let userBeatmapSelectorID = "user_beatmap_selector"
    private let footerHeight: CGFloat = 112
    @State private var backgroundUnavailable = false
    @State private var scrollTargetID: String?

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerBar

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.songs) { song in
                            SongRowView(song: song, isSelected: viewModel.selectedSongID == song.id) {
                                if song.id == userBeatmapSelectorID {
                                    onUserBeatmapsRequested?()
                                    return
                                }
                                viewModel.selectSong(song)
                            }
                            .id(song.id)
                            .onTapGesture(count: 2) {
                                if song.id != userBeatmapSelectorID, !song.isLocked {
                                    selectedSong = song.metadata
                                    selectedDifficulty = viewModel.selectedDifficulty
                                    if !viewModel.availableDifficulties.contains(selectedDifficulty) {
                                        selectedDifficulty = viewModel.availableDifficulties.first ?? .medium
                                    }
                                    onPlayRequested?()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, max(20, footerHeight + 8))
                }
                .scrollPosition(id: $scrollTargetID, anchor: .center)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: max(0, (footerHeight + 12).safeFinite))
                }
            }

            VStack {
                Spacer()
                playFooter
            }
        }
        .onAppear {
            if UIImage(named: "SetlistBackground") == nil {
                backgroundUnavailable = true
                debugLog("⚠️ SetlistBackground asset not found; using fallback gradient.")
            }
            viewModel.buildFromMetadata(songs, unlockedIDs: unlockedSongIDs, customBeatmap: customBeatmap, userBeatmapSelectorID: userBeatmapSelectorID)
            if let pre = preselectedSongID, let song = viewModel.songs.first(where: { $0.id == pre }) {
                viewModel.selectSong(song)
                selectedSong = song.metadata
                scrollTargetID = pre
            } else if let idx = viewModel.songs.firstIndex(where: { $0.id == selectedSong.id }) {
                viewModel.selectedSongID = viewModel.songs[idx].id
                viewModel.selectSong(viewModel.songs[idx])
            } else {
                viewModel.selectFirstIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if backgroundUnavailable {
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            Image("SetlistBackground")
                .resizable()
                .scaledToFill()
                .clipped()
                .ignoresSafeArea()
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: {
                RTHaptics.impact()
                dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("BACK")
                        .font(.system(size: 13, weight: .bold, design: .default))
                }
                .foregroundStyle(Color.white)
                .pencilTextStyle(color: .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            Spacer()
            Text("SETLIST")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .pencilTextStyle(color: .white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            Spacer()
            Color.clear.frame(width: 64, height: 36)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1),
                alignment: .bottom
            )
        )
    }

    private var playDisabled: Bool {
        viewModel.selectedSong == nil
        && viewModel.songs.first(where: { !$0.isLocked && $0.id != userBeatmapSelectorID }) == nil
    }

    private func playAction() {
        RTHaptics.impact()
        guard let song = viewModel.selectedSong ?? viewModel.songs.first(where: { !$0.isLocked }),
              song.id != userBeatmapSelectorID else {
            if viewModel.songs.contains(where: { $0.id == userBeatmapSelectorID }) {
                onUserBeatmapsRequested?()
            }
            return
        }
        selectedSong = song.metadata
        selectedDifficulty = viewModel.selectedDifficulty
        if !viewModel.availableDifficulties.contains(selectedDifficulty) {
            selectedDifficulty = viewModel.availableDifficulties.first ?? .medium
        }
        onPlayRequested?()
    }

    private var difficultyRow: some View {
        HStack(spacing: 8) {
            ForEach(Difficulty.allCases, id: \.self) { diff in
                let available = viewModel.availableDifficulties.contains(diff)
                Button {
                    guard available else { return }
                    RTHaptics.impact()
                    viewModel.selectedDifficulty = diff
                } label: {
                    Text(diff.rawValue.prefix(1))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(
                    available
                    ? Color.white
                    : Color.white.opacity(0.4)
                )
                .background(
                    Group {
                        if available, viewModel.selectedDifficulty == diff {
                            RTTheme.Colors.primaryStroke.opacity(0.45)
                        } else {
                            Color.black.opacity(0.28)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(viewModel.selectedDifficulty == diff ? RTTheme.Colors.primaryStroke : Color.white.opacity(0.10), lineWidth: 1)
                )
                .disabled(!available)
            }
        }
    }

    private var playFooter: some View {
        VStack(spacing: 8) {
            difficultyRow
                .padding(.horizontal, 20)

            Button(action: playAction) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text("PLAY")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RTTheme.Colors.primaryStroke.opacity(0.9), lineWidth: 1.5)
                )
            }
            .padding(.horizontal, 20)
            .disabled(playDisabled)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.22))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Previews

#Preview("Setlist - iPhone SE") {
    SongSelectionSetlistView(
        selectedSong: .constant(SongMetadata.default),
        selectedDifficulty: .constant(.medium),
        songs: Array(SongMetadata.library.prefix(6)),
        unlockedSongIDs: Set(SongMetadata.library.prefix(4).map(\.id)),
        customBeatmap: nil,
        onPlayRequested: {},
        onUserBeatmapsRequested: {}
    )
}

#Preview("Setlist - iPhone 16 Pro Max") {
    SongSelectionSetlistView(
        selectedSong: .constant(SongMetadata.default),
        selectedDifficulty: .constant(.medium),
        songs: Array(SongMetadata.library.prefix(8)),
        unlockedSongIDs: Set(SongMetadata.library.map(\.id)),
        customBeatmap: nil,
        onPlayRequested: {},
        onUserBeatmapsRequested: {}
    )
}
