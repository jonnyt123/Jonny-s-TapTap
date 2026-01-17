import SwiftUI
import UIKit

struct MainMenuView: View {
    @State private var showShop = false
    @State private var showSettings = false
    @State private var showBeatmapEditor = false
    @State private var showUserBeatmaps = false
    @State private var showDifficultyMenu = false
    @State private var lastUnlockedSongIDs: Set<String> = []
    @State private var shopPulse = false
    @AppStorage("hasVisitedShop") private var hasVisitedShop = false
    @Binding var selectedSong: SongMetadata
    @Binding var selectedDifficulty: Difficulty
    @Binding var isPlaying: Bool
    var availableDifficulties: Set<Difficulty>
    @ObservedObject var gameState: GameState

    var body: some View {
        ZStack {
            // Background image layer
            if let bgImage = loadBackgroundImage() {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
                    .offset(x: -24, y: -32)
            } else {
                Color.black
            }
            // Main menu UI
            VStack(spacing: 30) {
                settingsButtonSection
                Spacer().frame(height: 80)
                songSelectionSection
                controlsSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top)
            .padding(.horizontal, 24)
            .scaleEffect(0.75)
            .offset(x: -32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .sheet(isPresented: $showShop, onDismiss: {
            lastUnlockedSongIDs = gameState.unlockedSongIDs
            hasVisitedShop = true
        }) {
            ShopView(gameState: gameState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showBeatmapEditor) {
            BeatmapEditorView()
        }
        .sheet(isPresented: $showUserBeatmaps) {
            UserBeatmapPickerView { beatmap, url in
                let song = userSongMetadata(from: beatmap, url: url)
                selectedSong = song
                gameState.customBeatmap = beatmap
            }
        }
        .onChange(of: lastUnlockedSongIDs) { _, _ in
            if !gameState.unlockedSongIDs.contains(selectedSong.id) {
                if let firstUnlocked = SongMetadata.library.first(where: { gameState.unlockedSongIDs.contains($0.id) }) {
                    selectedSong = firstUnlocked
                }
            }
        }
    }
    // Computed property for shop button, now takes a binding
    private func shopButtonView(showShop: Binding<Bool>) -> some View {
        Button(action: { showShop.wrappedValue = true }) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 13, weight: .black))
                Text("SHOP")
                    .font(.system(size: 12, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.35, blue: 0.08),
                            Color(red: 0.65, green: 0.00, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    MetalSheen()
                        .opacity(0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
            )
            .cornerRadius(10)
            .shadow(color: Color(red: 1.0, green: 0.35, blue: 0.1).opacity(0.6), radius: 10, y: 4)
            .scaleEffect(shopPulse ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: shopPulse)
        }
        .onAppear { shopPulse = true }
    }

    private var settingsButtonSection: some View {
        HStack {
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .padding(.top, 40)
        .padding(.trailing, 24)
    }

    private var songSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT SONG")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 4)
                .padding(.horizontal)
            HStack {
                Image(systemName: "flame.circle.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.1))
                Text("Tap Coins: \(gameState.tapCoins)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                shopButtonView(showShop: $showShop)
            }
            .padding(.horizontal)
            Button(action: { GameCenterManager.shared.presentLeaderboards() }) {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                        .font(.system(size: 12, weight: .bold))
                    Text("LEADERBOARDS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            .padding(.horizontal)
            LevelProgressBar(totalXP: gameState.totalXP, thresholds: LevelingCurve.defaultThresholds)
                .padding(.horizontal)
            if !hasVisitedShop {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.15))
                    Text("Unlock more songs in the Shop")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(availableSongList()) { song in
                        Button(action: {
                            selectedSong = song
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.title.uppercased())
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(song.artist)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                    if song.id == "user_beatmap" {
                                        Text("USER BEATMAP")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("BPM \(Int(song.bpm))")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("\(song.lanes)-LANE")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                if selectedSong.id == song.id {
                                    Image(systemName: "bolt.circle.fill")
                                        .foregroundStyle(Color(red: 0.85, green: 0.0, blue: 0.05))
                                        .font(.system(size: 20, weight: .bold))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: metalCardColors(for: song, unlocked: true),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ).opacity(0.9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedSong.id == song.id ? Color(red: 0.8, green: 0.0, blue: 0.05) : Color.white.opacity(0.12), lineWidth: 2.0)
                            )
                        }
                        .cornerRadius(12)
                        .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.8), radius: 10, y: 4)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.visible)
        }
        .padding(.vertical, 12)
    }

    private func availableSongList() -> [SongMetadata] {
        var items = SongMetadata.library.filter { gameState.unlockedSongIDs.contains($0.id) }
        if let custom = gameState.customBeatmap {
            let song = userSongMetadata(from: custom, url: BeatmapStore.documentsURL(filename: custom.song.filename))
            items.insert(song, at: 0)
        }
        return items
    }

    private var controlsSection: some View {
        VStack(spacing: 10) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showDifficultyMenu.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showDifficultyMenu ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                    Text(showDifficultyMenu ? "HIDE" : "DIFFICULTY: \(selectedDifficulty.rawValue.uppercased())")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.7, green: 0.0, blue: 0.05).opacity(0.8), lineWidth: 1.5)
            )

            if showDifficultyMenu {
                HStack(spacing: 6) {
                    ForEach(Difficulty.allCases, id: \ .self) { difficulty in
                        let isAvailable = availableDifficulties.contains(difficulty)
                        Button(action: {
                            guard isAvailable else { return }
                            selectedDifficulty = difficulty
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showDifficultyMenu = false
                            }
                        }) {
                            VStack(spacing: 2) {
                                Text(difficulty.rawValue.prefix(1))
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                Text(difficulty.rawValue)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundColor(
                            isAvailable ? (selectedDifficulty == difficulty ? Color(red: 1.0, green: 0.2, blue: 0.2) : .white) : .gray
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isAvailable ?
                                (selectedDifficulty == difficulty ? Color(red: 0.35, green: 0.00, blue: 0.05).opacity(0.6) : Color.white.opacity(0.08))
                                : Color.white.opacity(0.05)
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedDifficulty == difficulty ? Color(red: 0.8, green: 0.0, blue: 0.05) : Color.clear, lineWidth: 2)
                        )
                        .disabled(!isAvailable)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            }

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isPlaying = true
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("START GAME")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.65, green: 0.00, blue: 0.05),
                        Color(red: 0.35, green: 0.00, blue: 0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color(red: 0.6, green: 0.0, blue: 0.0).opacity(0.7), radius: 12, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.8, green: 0.0, blue: 0.05).opacity(0.9), lineWidth: 1.5)
            )
            .disabled(!gameState.unlockedSongIDs.contains(selectedSong.id) && selectedSong.id != "user_beatmap")
            
            Button(action: { showBeatmapEditor = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 16, weight: .bold))
                    Text("BEATMAP EDITOR")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            
            Button(action: { showUserBeatmaps = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("LOAD USER BEATMAP")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .padding(.bottom, 40)
        .padding(.horizontal)
        }

private func loadBackgroundImage() -> UIImage? {
    // Try to load from bundle
    if let path = Bundle.main.path(forResource: "main_menu_bg", ofType: "jpg"),
       let image = UIImage(contentsOfFile: path) {
        return image
    }
    if let path = Bundle.main.path(forResource: "main_menu_bg", ofType: "png"),
       let image = UIImage(contentsOfFile: path) {
        return image
    }
    return nil
}

// MARK: - Metal Theme Helpers

private func metalTitleFont(_ size: CGFloat) -> Font {
    if UIFont(name: "MetalDisplay", size: size) != nil {
        return .custom("MetalDisplay", size: size)
    } else if UIFont(name: "JonnysTapTap", size: size) != nil {
        return .custom("JonnysTapTap", size: size)
    } else if UIFont(name: "Copperplate-Bold", size: size) != nil {
        return .custom("Copperplate-Bold", size: size)
    }
    return .system(size: size, weight: .black, design: .default)
}

private func metalBrandFont(_ size: CGFloat) -> Font {
    if UIFont(name: "MetalDisplay", size: size) != nil {
        return .custom("MetalDisplay", size: size)
    } else if UIFont(name: "JonnysTapTap", size: size) != nil {
        return .custom("JonnysTapTap", size: size)
    } else if UIFont(name: "Copperplate", size: size) != nil {
        return .custom("Copperplate", size: size)
    }
    return .system(size: size, weight: .heavy, design: .default)
}

private func metalCardColors(for song: SongMetadata, unlocked: Bool) -> [Color] {
    if !unlocked {
        return [Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.18, green: 0.00, blue: 0.03)]
    }
    if song.id == "user_beatmap" {
        return [Color(red: 0.10, green: 0.10, blue: 0.14), Color(red: 0.65, green: 0.25, blue: 0.05)]
    }
    if song.lanes == 4 {
        return [Color(red: 0.15, green: 0.15, blue: 0.18), Color(red: 0.40, green: 0.00, blue: 0.06)]
    }
    if song.bpm >= 120 {
        return [Color(red: 0.14, green: 0.14, blue: 0.17), Color(red: 0.05, green: 0.20, blue: 0.40)]
    }
    return [Color(red: 0.14, green: 0.14, blue: 0.17), Color(red: 0.22, green: 0.00, blue: 0.28)]
}

private struct MetalStripes: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let count = Int(width / 8)
            ZStack {
                ForEach(0..<(count + 20), id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 2)
                        .offset(x: CGFloat(i) * 8)
                }
            }
            .rotationEffect(.degrees(12))
            .offset(y: -geo.size.height * 0.2)
        }
        .allowsHitTesting(false)
    }
}

private struct MetalSheen: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.15), Color.white.opacity(0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
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

// Add missing closing brace for MainMenuView
}
