import SwiftUI
import UIKit
import AVFoundation
import SpriteKit

struct MainMenuView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var showShop = false
    @State private var showSettings = false
    @State private var showBeatmapEditor = false
    @State private var showUserBeatmaps = false
    @State private var showMultiplayer = false
    @State private var showAvatarCreator = false
    @State private var showDifficultyMenu = false
    @State private var lastUnlockedSongIDs: Set<String> = []
    @State private var shopPulse = false
    @State private var menuHeight: CGFloat = 0
    @State private var previewPlayer: AVAudioPlayer?
    @State private var previewStopWorkItem: DispatchWorkItem?
    @State private var scrollTargetID: String?
    @State private var showSongSelect = false
    @State private var preselectedSongIDForSetlist: String?
    @State private var menuScene = MainMenuScene(size: .zero)
    @AppStorage("hasVisitedShop") private var hasVisitedShop = false
    @Binding var selectedSong: SongMetadata
    @Binding var selectedDifficulty: Difficulty
    @Binding var isPlaying: Bool
    var availableDifficulties: Set<Difficulty>
    @ObservedObject var gameState: GameState
    var onStartGame: (() -> Void)? = nil
    @State private var debugLayout = false

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: menuScene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .focusable(false)
                .onAppear {
                    configureMenuScene(size: geo.size, safeAreaInsets: geo.safeAreaInsets)
                    updateMenuSceneData()
                }
                .onChange(of: geo.size) { _, newSize in
                    configureMenuScene(size: newSize, safeAreaInsets: geo.safeAreaInsets)
                }
                .onChange(of: geo.safeAreaInsets) { _, newInsets in
                    configureMenuScene(size: geo.size, safeAreaInsets: newInsets)
                }
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showShop, onDismiss: {
            lastUnlockedSongIDs = gameState.unlockedSongIDs
            hasVisitedShop = true
        }) {
            ShopView(gameState: gameState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(gameState: gameState)
        }
        .fullScreenCover(isPresented: $showSongSelect, onDismiss: {
            preselectedSongIDForSetlist = nil
        }) {
            SongSelectionSetlistView(
                selectedSong: $selectedSong,
                selectedDifficulty: $selectedDifficulty,
                songs: availableSongList(),
                unlockedSongIDs: gameState.unlockedSongIDs,
                customBeatmap: gameState.customBeatmap,
                onPlayRequested: {
                    showSongSelect = false
                    gameState.setSong(selectedSong)
                    gameState.setDifficulty(selectedDifficulty)
                    gameState.reset()
                    if let onStartGame {
                        onStartGame()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                isPlaying = true
                            }
                        }
                    }
                },
                onUserBeatmapsRequested: {
                    showSongSelect = false
                    showUserBeatmaps = true
                },
                preselectedSongID: preselectedSongIDForSetlist
            )
        }
        .sheet(isPresented: $showAvatarCreator, onDismiss: {
            updateMenuSceneData()
        }) {
            AvatarCreatorView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarDidChange)) { _ in
            updateMenuSceneData()
        }
        .sheet(isPresented: $showBeatmapEditor) {
            BeatmapEditorView(onBeatmapSaved: { _ in
                showBeatmapEditor = false
                if let (beatmap, url) = latestUserBeatmapInDocuments() {
                    selectedSong = userSongMetadata(from: beatmap, url: url)
                    gameState.customBeatmap = beatmap
                }
                preselectedSongIDForSetlist = "user_beatmap"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showSongSelect = true
                }
            })
        }
        .sheet(isPresented: $showUserBeatmaps) {
            UserBeatmapPickerView(
                onSelect: { beatmap, url in
                    let song = userSongMetadata(from: beatmap, url: url)
                    selectedSong = song
                    gameState.customBeatmap = beatmap
                },
                onCreateBeatmapRequested: {
                    showUserBeatmaps = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showBeatmapEditor = true
                    }
                }
            )
        }
        .sheet(isPresented: $showMultiplayer) {
            MultiplayerLobbyView()
        }
        .onAppear {
            startPreview(for: selectedSong)
            scrollTargetID = selectedSong.id
            updateMenuSceneData()
        }
        .onChange(of: selectedSong.id) { _, _ in
            startPreview(for: selectedSong)
            scrollTargetID = selectedSong.id
        }
        .onDisappear {
            stopPreview()
        }
        .onChange(of: accountManager.state.username ?? "") { _, _ in
            updateMenuSceneData()
        }
        .onChange(of: accountManager.state.level) { _, _ in
            updateMenuSceneData()
        }
        .onChange(of: accountManager.state.coinsBalance) { _, _ in
            updateMenuSceneData()
        }
        .onChange(of: lastUnlockedSongIDs) { _, _ in
            if !gameState.unlockedSongIDs.contains(selectedSong.id) {
                if let firstUnlocked = SongMetadata.library.first(where: { gameState.unlockedSongIDs.contains($0.id) }) {
                    selectedSong = firstUnlocked
                }
            }
        }
    }

    private func MenuGroup() -> some View {
        GeometryReader { geo in
            VStack(spacing: 22) {
                Spacer().frame(height: min(60, geo.size.height * 0.06))
                songSelectionSection
                controlsSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, geo.size.height * 0.15)
            .padding(.horizontal, 4)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { menuHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newValue in
                        if abs(menuHeight - newValue) > 0.5 {
                            menuHeight = newValue
                        }
                    }
            }
        )
    }

    private func configureMenuScene(size: CGSize, safeAreaInsets: EdgeInsets) {
        menuScene.scaleMode = .resizeFill
        menuScene.size = size
        menuScene.safeAreaInsets = UIEdgeInsets(
            top: safeAreaInsets.top,
            left: safeAreaInsets.leading,
            bottom: safeAreaInsets.bottom,
            right: safeAreaInsets.trailing
        )
        menuScene.onPlayTapped = { showSongSelect = true }
        menuScene.onShopTapped = { showShop = true }
        menuScene.onSettingsTapped = { showSettings = true }
        menuScene.onMultiplayerTapped = { showMultiplayer = true }
        menuScene.onAvatarTapped = { showAvatarCreator = true }
        menuScene.onBeatmapEditorTapped = { showBeatmapEditor = true }
        menuScene.onUserBeatmapsTapped = { showUserBeatmaps = true }
    }

    private func updateMenuSceneData() {
        let username = resolvedUsername()
        let level = max(1, accountManager.state.level)
        let coins = accountManager.state.coinsBalance
        let avatarImage = AvatarStore.shared.currentAvatarImage()
        menuScene.updatePlayerData(username: username, level: level, coins: coins, avatarImage: avatarImage)
    }

    private func resolvedUsername() -> String {
        if accountManager.isSignedIn, let name = accountManager.state.username, !name.isEmpty {
            return name
        }
        if let name = accountManager.state.username, !name.isEmpty {
            return name
        }
        return "Player"
    }

    private func loadSavedAvatarImage() -> UIImage? {
        // Deprecated: use AvatarStore.shared.currentAvatarImage().
        return AvatarStore.shared.currentAvatarImage()
    }

    private func debugOverlay(size: CGSize, scale: CGFloat = 1) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.5, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height * 0.5))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
            }
            .stroke(Color.green.opacity(0.6), lineWidth: 1)
            Rectangle()
                .stroke(Color.red.opacity(0.8), lineWidth: 2)
                .frame(width: size.width, height: size.height)
            Circle()
                .fill(Color.yellow)
                .frame(width: 6, height: 6)
                .position(x: size.width * 0.5, y: size.height * 0.5)
        }
        .allowsHitTesting(false)
    }
    // Computed property for shop button, now takes a binding
    private func shopButtonView(showShop: Binding<Bool>) -> some View {
        Button(action: { RTHaptics.impact(); showShop.wrappedValue = true }) {
            HStack(spacing: RTTheme.Spacing.md) {
                Image(systemName: "cart.fill")
                    .font(RTTheme.Fonts.callout(13))
                Text("SHOP")
                    .font(RTTheme.Fonts.caption(12))
            }
            .foregroundColor(RTTheme.Colors.textPrimary)
            .padding(.horizontal, RTTheme.Spacing.xl)
            .padding(.vertical, RTTheme.Spacing.medium)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [RTTheme.Colors.primaryStart, RTTheme.Colors.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    MetalSheen()
                        .opacity(0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
            )
            .cornerRadius(RTTheme.Radius.card)
            .shadow(color: RTTheme.Colors.accentHighlight.opacity(0.6), radius: RTTheme.Shadow.glow(color: .white).radius, y: 4)
            .scaleEffect(shopPulse ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: shopPulse)
        }
        .onAppear { shopPulse = true }
    }

    private var settingsButtonSection: some View {
        Button(action: { RTHaptics.impact(); showSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(RTTheme.Fonts.body(16))
                .foregroundColor(RTTheme.Colors.textPrimary)
                .padding(RTTheme.Spacing.lg)
                .background(Color.black.opacity(0.25))
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }

    private var songSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer().frame(height: 2)
            HStack {
                Text("SELECT SONG")
                    .font(RTTheme.Fonts.callout(14))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                Spacer()
                shopButtonView(showShop: $showShop)
            }
            .padding(.horizontal)
            playerStatusCard
            if !hasVisitedShop {
                HStack(spacing: RTTheme.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(RTTheme.Colors.accentHighlight)
                    Text("Unlock more songs in the Shop")
                        .font(RTTheme.Fonts.caption(11))
                        .foregroundStyle(RTTheme.Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(RTTheme.Fonts.label(10))
                        .foregroundStyle(RTTheme.Colors.textMuted)
                }
                .padding(.vertical, RTTheme.Spacing.sm)
                .padding(.horizontal, RTTheme.Spacing.lg)
                .background(Color.black.opacity(0.25))
                .cornerRadius(RTTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.medium)
                        .stroke(RTTheme.Colors.surfaceStrokeLight, lineWidth: 1)
                )
                .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(availableSongList()) { song in
                        Button(action: {
                            if song.id == userBeatmapSelectorID {
                                showUserBeatmaps = true
                                return
                            }
                            selectedSong = song
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.title.uppercased())
                                        .font(RTTheme.Fonts.headline(16))
                                        .foregroundColor(RTTheme.Colors.textPrimary)
                                    if song.id == userBeatmapSelectorID {
                                        Text("TAP TO LOAD")
                                            .font(RTTheme.Fonts.caption(12))
                                            .foregroundColor(RTTheme.Colors.textMuted)
                                    } else {
                                        Text(song.artist)
                                            .font(RTTheme.Fonts.caption(12))
                                            .foregroundColor(RTTheme.Colors.textMuted)
                                        if song.id == "user_beatmap" {
                                            Text("USER BEATMAP")
                                                .font(RTTheme.Fonts.label(10))
                                                .foregroundColor(RTTheme.Colors.accentOrangeLight)
                                        }
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    if song.id != userBeatmapSelectorID {
                                        Text("BPM \(Int(song.bpm))")
                                            .font(RTTheme.Fonts.caption(11))
                                            .foregroundColor(RTTheme.Colors.textMuted)
                                        Text("\(song.lanes)-LANE")
                                            .font(RTTheme.Fonts.caption(11))
                                            .foregroundColor(RTTheme.Colors.textMuted)
                                    } else {
                                        Text("USER")
                                            .font(RTTheme.Fonts.caption(11))
                                            .foregroundColor(RTTheme.Colors.textMuted)
                                    }
                                }
                                if selectedSong.id == song.id && song.id != userBeatmapSelectorID {
                                    Image(systemName: "bolt.circle.fill")
                                        .foregroundStyle(RTTheme.Colors.primaryStroke)
                                        .font(RTTheme.Fonts.body(20))
                                }
                            }
                            .padding(12)
                            .frame(width: selectedSong.id == song.id ? 220 : 200, height: selectedSong.id == song.id ? 160 : 140)
                            .background(
                                LinearGradient(
                                    colors: song.id == userBeatmapSelectorID
                                        ? [Color(red: 0.10, green: 0.12, blue: 0.18), Color(red: 0.02, green: 0.02, blue: 0.04)]
                                        : metalCardColors(for: song, unlocked: true),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ).opacity(0.9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                                    .stroke(selectedSong.id == song.id ? RTTheme.Colors.primaryStroke : RTTheme.Colors.surfaceStroke, lineWidth: 2.0)
                            )
                        }
                        .scaleEffect(selectedSong.id == song.id ? 1.06 : 1.0)
                        .cornerRadius(RTTheme.Radius.button)
                        .shadow(color: RTTheme.Shadow.card().color, radius: RTTheme.Shadow.card().radius, y: RTTheme.Shadow.card().y)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollTargetID, anchor: .center)
            .onChange(of: scrollTargetID) { _, newValue in
                guard let newValue, newValue != selectedSong.id else { return }
                if newValue == userBeatmapSelectorID { return }
                if let song = availableSongList().first(where: { $0.id == newValue }) {
                    selectedSong = song
                }
            }
            .scrollIndicators(.visible)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                        .fill(Color.black.opacity(0.14))
                    RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                        .stroke(RTTheme.Colors.primaryStroke.opacity(0.7), lineWidth: 3)
                    RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                        .stroke(RTTheme.Colors.accentOrangeLight.opacity(0.25), lineWidth: 6)
                        .blur(radius: 4)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                    .stroke(Color.black.opacity(0.5), lineWidth: 2)
            )
            .frame(height: 190)
        }
        .padding(.vertical, 12)
        .padding(.top, 6)
    }

    private var playerStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LEVEL \(accountManager.state.level)")
                    .font(RTTheme.Fonts.callout(13))
                    .foregroundColor(RTTheme.Colors.textPrimary)
                Text("· \(ProgressionTier.rankName(for: accountManager.state.level))")
                    .font(RTTheme.Fonts.label(10))
                    .foregroundColor(RTTheme.Colors.textMuted)
                Spacer()
                Text(accountManager.statusText.uppercased())
                    .font(RTTheme.Fonts.label(10))
                    .foregroundColor(RTTheme.Colors.accentOrangeLight)
            }
            LevelProgressBar(totalXP: gameState.totalXP, thresholds: LevelingCurve.defaultThresholds)
                Text("TOTAL XP \(gameState.totalXP)")
                .font(RTTheme.Fonts.label(10))
                .foregroundColor(RTTheme.Colors.textMuted)
        }
        .padding(RTTheme.Spacing.medium)
        .background(
            LinearGradient(
                colors: [RTTheme.Colors.primaryDarkEnd, RTTheme.Colors.backgroundDarkEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                .stroke(RTTheme.Colors.primaryStroke.opacity(0.9), lineWidth: 1.5)
        )
        .cornerRadius(RTTheme.Radius.card)
        .padding(.horizontal)
    }

    private var displayName: String {
        if accountManager.isSignedIn, let name = accountManager.state.username, !name.isEmpty {
            return name
        }
        return "Guest"
    }

    private func availableSongList() -> [SongMetadata] {
        var items = SongMetadata.library
        if let custom = gameState.customBeatmap {
            let song = userSongMetadata(from: custom, url: BeatmapStore.documentsURL(filename: custom.song.filename))
            items.insert(song, at: 0)
        }
        items.append(userBeatmapSelectorSong())
        return items
    }

    private var userBeatmapSelectorID: String { "user_beatmap_selector" }

    private func userBeatmapSelectorSong() -> SongMetadata {
        SongMetadata(
            id: userBeatmapSelectorID,
            title: "User Beatmaps",
            artist: "Tap to load",
            audioName: "user_beatmap",
            audioExtension: "mp3",
            chartFiles: ChartFiles(same: "user_beatmap"),
            lanes: 4,
            bpm: 0,
            primaryColors: [.gray, .black],
            accent: .gray
        )
    }

    private func startPreview(for song: SongMetadata) {
        stopPreview()
        guard let url = resolvePreviewURL(for: song) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.7
            let previewLength = 20.0
            let maxStart = max(0, player.duration - previewLength)
            let startTime = maxStart > 0 ? Double.random(in: 0...maxStart) : 0
            player.currentTime = startTime
            player.play()
            previewPlayer = player
            let workItem = DispatchWorkItem { [self] in
                stopPreview()
            }
            previewStopWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + previewLength, execute: workItem)
        } catch {
            previewPlayer = nil
        }
    }

    private func stopPreview() {
        previewStopWorkItem?.cancel()
        previewStopWorkItem = nil
        previewPlayer?.stop()
        previewPlayer = nil
    }

    private func resolvePreviewURL(for song: SongMetadata) -> URL? {
        if let bundleURL = Bundle.main.url(forResource: song.audioName, withExtension: song.audioExtension) {
            return bundleURL
        }
        if let resourcesBundle = Bundle.main.url(forResource: "Resources", withExtension: "bundle") {
            let bundleTrackURL = resourcesBundle.appendingPathComponent(song.audioName).appendingPathExtension(song.audioExtension)
            if FileManager.default.fileExists(atPath: bundleTrackURL.path) {
                return bundleTrackURL
            }
        }
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docPath = docDir.appendingPathComponent(song.audioName).appendingPathExtension(song.audioExtension)
        if FileManager.default.fileExists(atPath: docPath.path) {
            return docPath
        }
        return nil
    }

    private var controlsSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(Difficulty.allCases, id: \ .self) { difficulty in
                    let isAvailable = availableDifficulties.contains(difficulty)
                    Button(action: {
                        guard isAvailable else { return }
                        selectedDifficulty = difficulty
                    }) {
                        VStack(spacing: 2) {
                            Text(difficulty.rawValue.prefix(1))
                                .font(RTTheme.Fonts.body(16))
                            Text(difficulty.rawValue)
                                .font(RTTheme.Fonts.small(9))
                        }
                    }
                    .foregroundColor(
                        isAvailable ? (selectedDifficulty == difficulty ? RTTheme.Colors.selectedRedBright : RTTheme.Colors.textPrimary) : RTTheme.Colors.textDisabled
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RTTheme.Spacing.md)
                    .background(
                        isAvailable
                            ? (selectedDifficulty == difficulty ? RTTheme.Colors.primaryStroke.opacity(0.6) : RTTheme.Colors.surfaceMuted)
                            : RTTheme.Colors.surfaceSubtle
                    )
                    .cornerRadius(RTTheme.Radius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.medium)
                            .stroke(selectedDifficulty == difficulty ? RTTheme.Colors.primaryStroke : Color.clear, lineWidth: 2)
                    )
                    .disabled(!isAvailable)
                }
            }
            .padding(.horizontal)

            RTPrimaryButton(title: "START GAME", icon: "play.fill") {
                RTHaptics.impact()
                withAnimation(RTTheme.Animation.spring) {
                    isPlaying = true
                }
            }
            .disabled(!gameState.unlockedSongIDs.contains(selectedSong.id) && selectedSong.id != "user_beatmap")

            RTSecondaryButton(title: "BEATMAP EDITOR", icon: "pencil.and.outline") {
                RTHaptics.impact()
                showBeatmapEditor = true
            }

            RTSecondaryButton(title: "MULTIPLAYER", icon: "person.3.fill") {
                RTHaptics.impact()
                showMultiplayer = true
            }
        }
        .padding(.bottom, 6)
        .padding(.top, 10)
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

private func latestUserBeatmapInDocuments() -> (Beatmap, URL)? {
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
          let urls = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.contentModificationDateKey]) else {
        return nil
    }
    let userJson = urls.filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.contains("_user_") }
    let withDates = userJson.compactMap { url -> (URL, Date)? in
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else { return nil }
        return (url, date)
    }
    guard let latest = withDates.sorted(by: { $0.1 > $1.1 }).first,
          let beatmap = try? BeatmapStore.load(from: latest.0) else {
        return nil
    }
    return (beatmap, latest.0)
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
