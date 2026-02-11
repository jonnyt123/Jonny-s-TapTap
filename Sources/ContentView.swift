import SwiftUI
import SpriteKit
import UIKit

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var multiplayerStore = MultiplayerStore.shared
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var scene: GameScene?
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var selectedSong: SongMetadata = .default
    @State private var availableDifficulties: Set<Difficulty> = Set(Difficulty.allCases)
    @State private var multiplayerStartAt: Date?
    
    var body: some View {
        ZStack {
            if !isPlaying {
                MainMenuView(selectedSong: $selectedSong, selectedDifficulty: $selectedDifficulty, isPlaying: $isPlaying, availableDifficulties: availableDifficulties, gameState: gameState, onStartGame: startGame)
                    .accessibilityIdentifier("mainMenu")
                    .transition(AnyTransition.opacity)
            } else {
                gameView
                    .transition(AnyTransition.opacity)
            }
        }
        .ignoresSafeArea(isPlaying ? .all : [])
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .onAppear {
            gameState.loadProgress()
            gameState.setSong(selectedSong)
            gameState.setDifficulty(selectedDifficulty)
            refreshAvailability(for: selectedSong)
        }
        .fullScreenCover(isPresented: $accountManager.requiresUsername) {
            CreateUsernameView()
        }
        .onChange(of: selectedSong) { _, newSong in
            gameState.setSong(newSong)
            refreshAvailability(for: newSong)
            if !availableDifficulties.contains(selectedDifficulty) {
                selectedDifficulty = availableDifficulties.first ?? .medium
                gameState.setDifficulty(selectedDifficulty)
            }
            // Extra stop to ensure previous audio is fully halted when switching songs from the menu
            scene?.stop()
            scene = nil
        }
        .onChange(of: multiplayerStore.pendingStart) { _, payload in
            guard let payload else { return }
            multiplayerStore.clearPendingStart()
            if let song = SongMetadata.library.first(where: { $0.id == payload.songId }) {
                selectedSong = song
            }
            selectedDifficulty = payload.difficulty
            multiplayerStartAt = payload.startAt
            isPlaying = true
        }
    }
    
    private static let minValidSize: CGFloat = 2

    private var gameView: some View {
        GeometryReader { geo in
            let validSize = isGameplaySizeValid(geo.size)
            ZStack {
                if validSize, let scene = scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: preferredFPS(), options: [.ignoresSiblingOrder])
                        .frame(width: geo.size.width, height: geo.size.height)
                        .focusable(false)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                overlay

                if !settings.disableBackgroundAnimations && settings.backgroundIntensity != .static {
                    BloodRainView()
                        .allowsHitTesting(false)
                }

                if isPaused {
                    pauseOverlay
                }

                if gameState.isFailed {
                    failureOverlay
                }

                if gameState.isCompleted && !gameState.isFailed && ((scene?.gamePhase) == .ended) {
                    resultsOverlay
                }
            }
            .onAppear {
                if !validSize {
                    debugLog("GameView: invalid geo on appear width=\(geo.size.width) height=\(geo.size.height), skipping scene config")
                }
                if isPlaying && scene == nil && validSize {
                    createSceneIfNeeded(size: geo.size, safeAreaInsets: geo.safeAreaInsets)
                }
                if let s = scene, validSize {
                    applySafeAreaToScene(s, insets: geo.safeAreaInsets)
                }
            }
            .onChange(of: geo.size) { _, newSize in
                let newValid = isGameplaySizeValid(newSize)
                if !newValid {
                    debugLog("GameView: invalid geo on change width=\(newSize.width) height=\(newSize.height), skipping")
                    return
                }
                scene?.stop()
                scene = nil
                if isPlaying {
                    createSceneIfNeeded(size: newSize, safeAreaInsets: geo.safeAreaInsets)
                    if let s = scene {
                        applySafeAreaToScene(s, insets: geo.safeAreaInsets)
                    }
                }
            }
            .onChange(of: geo.safeAreaInsets) { _, newInsets in
                if let s = scene, validSize {
                    applySafeAreaToScene(s, insets: newInsets)
                }
            }
            .onChange(of: isPlaying) { _, newValue in
                if newValue {
                    if scene == nil {
                        prepareAndStartScene()
                    }
                } else {
                    scene?.stop()
                    scene = nil
                }
            }
        }
    }

    /// True when container size is valid for SpriteKit (avoids zero/negative/non-finite and "Invalid frame dimension").
    private func isGameplaySizeValid(_ size: CGSize) -> Bool {
        guard size.width > Self.minValidSize, size.height > Self.minValidSize else { return false }
        return size.width.isFinite && size.height.isFinite
    }

    /// Injects safe area insets from SwiftUI into the scene and runs layout so HUD/lanes use playableRect.
    private func applySafeAreaToScene(_ scene: GameScene, insets: EdgeInsets) {
        scene.safeAreaInsets = UIEdgeInsets(
            top: insets.top,
            left: insets.leading,
            bottom: insets.bottom,
            right: insets.trailing
        )
        scene.layout()
    }

    /// Creates and assigns the gameplay scene once; only when geometry is valid. Scene is kept in @State and only resized on geo changes.
    private func createSceneIfNeeded(size: CGSize, safeAreaInsets insets: EdgeInsets = EdgeInsets()) {
        guard isPlaying, scene == nil else { return }
        guard isGameplaySizeValid(size) else { return }
        let safe = safeSize(size)
        let newScene = GameScene(size: safe)
        // Ensure gameplay scene uses centered anchor + .resizeFill BEFORE presentation
        newScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        newScene.scaleMode = .resizeFill
        newScene.safeAreaInsets = UIEdgeInsets(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
        newScene.configure(song: selectedSong, difficulty: selectedDifficulty, gameState: gameState)
        if let delay = multiplayerStartDelay() {
            newScene.musicStartDelayOverride = delay
        }
        scene = newScene
    }

    /// Call when user taps play from song select; prepares state and sets isPlaying. Scene is created in gameView when geometry is available.
    private func startGame() {
        scene?.stop()
        scene = nil
        gameState.reset()
        gameState.setSong(selectedSong)
        gameState.setDifficulty(selectedDifficulty)
        debugLogGameStart(context: "startGame")
        isPlaying = true
    }

    /// Prepare state when isPlaying became true without going through startGame (e.g. multiplayer). Scene is created in gameView when geometry is available.
    private func prepareAndStartScene() {
        scene?.stop()
        scene = nil
        gameState.reset()
        gameState.setSong(selectedSong)
        gameState.setDifficulty(selectedDifficulty)
        debugLogGameStart(context: "isPlaying change")
    }

    private func multiplayerStartDelay() -> TimeInterval? {
        guard let startAt = multiplayerStartAt else { return nil }
        let nowMs = Date().timeIntervalSince1970 * 1000
        let serverNowMs = nowMs + multiplayerStore.serverTimeOffsetMs
        let delayMs = max(0, startAt.timeIntervalSince1970 * 1000 - serverNowMs)
        return delayMs / 1000.0
    }

    private func debugLogGameStart(context: String) {
        debugLog("DEBUG START [\(context)] song=\(selectedSong.id) difficulty=\(selectedDifficulty.rawValue) failed=\(gameState.isFailed) completed=\(gameState.isCompleted)")
    }

    private func preferredFPS() -> Int {
        switch settings.fpsCap {
        case .auto: return 120
        case .fps60: return 60
        case .fps120: return 120
        case .unlimited: return 0
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            RTTheme.Colors.backgroundModalScrim
                .blur(radius: 4)
            VStack(spacing: RTTheme.Spacing.large) {
                VStack(spacing: RTTheme.Spacing.lg) {
                    Text("PAUSED")
                        .font(RTTheme.Fonts.title(48))
                        .foregroundStyle(
                            LinearGradient(colors: [RTTheme.Colors.blueStart, RTTheme.Colors.blueEnd], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: RTTheme.Colors.blueStart, radius: 20)
                    Divider()
                        .background(RTTheme.Colors.blueStart.opacity(0.5))
                }
                VStack(spacing: RTTheme.Spacing.xl) {
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(RTTheme.Colors.accentOrange)
                            .font(RTTheme.Fonts.body(18))
                        Text("Tap Coins: \(gameState.tapCoins)")
                            .font(RTTheme.Fonts.callout(14))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(RTTheme.Spacing.lg)
                    .background(RTTheme.Colors.surfaceMuted)
                    .cornerRadius(RTTheme.Radius.button)
                    RTActionButton(title: "Resume", icon: "play.fill", style: .success) {
                        RTHaptics.impact()
                        isPaused = false
                        scene?.resume()
                    }
                    RTActionButton(title: "Exit", icon: "xmark.circle.fill", style: .primary) {
                        RTHaptics.impact()
                        scene?.stop()
                        gameState.reset()
                        isPaused = false
                        isPlaying = false
                    }
                }
                .padding(RTTheme.Spacing.screen)
                .background(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.overlay)
                        .fill(RTTheme.Colors.surfaceMuted)
                        .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.overlay).stroke(RTTheme.Colors.surfaceStroke, lineWidth: 1))
                )
            }
            .padding(RTTheme.Spacing.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game paused")
        .accessibilityAddTraits(.isModal)
        .transition(.scale.combined(with: .opacity))
    }
    
    private var failureOverlay: some View {
        ZStack {
            RTTheme.Colors.backgroundModalScrim
            VStack(spacing: RTTheme.Spacing.large) {
                Text("FAILED!")
                    .font(RTTheme.Fonts.title(72))
                    .foregroundStyle(RTTheme.Colors.selectedRed)
                    .shadow(color: RTTheme.Colors.selectedRed, radius: 30)
                    .scaleEffect(1.1)
                VStack(spacing: RTTheme.Spacing.xxl) {
                    HStack {
                        Text("Missed Notes:")
                            .font(RTTheme.Fonts.body(18))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(gameState.missedNotes)")
                            .font(RTTheme.Fonts.headline(24))
                            .foregroundStyle(RTTheme.Colors.selectedRed)
                    }
                    HStack {
                        Text("Final Score:")
                            .font(RTTheme.Fonts.body(18))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(gameState.score)")
                            .font(RTTheme.Fonts.headline(24))
                            .foregroundStyle(RTTheme.Colors.accentAmber)
                    }
                }
                .padding(RTTheme.Spacing.block)
                .background(RTTheme.Colors.surfaceMuted)
                .cornerRadius(RTTheme.Radius.panel)
                RTActionButton(title: "Return to Menu", icon: "house.fill", style: .primary) {
                    RTHaptics.impact()
                    scene?.stop()
                    gameState.reset()
                    isPlaying = false
                }
                .padding(.horizontal, RTTheme.Spacing.large)
            }
            .padding(RTTheme.Spacing.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game over. Failed.")
        .accessibilityAddTraits(.isModal)
    }
    
    private var overlay: some View {
        GeometryReader { geo in
            let topSafe = geo.safeAreaInsets.top
            VStack(spacing: 0) {
                // Top bar with glassmorphic effect - compact layout; respect safe area
                HStack(alignment: .center, spacing: RTTheme.Spacing.lg) {
                    Button(action: {
                        RTHaptics.impact()
                        isPaused = true
                        scene?.pause()
                    }) {
                        Image(systemName: "pause.fill")
                            .font(RTTheme.Fonts.body(16))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(RTTheme.Colors.surfaceMuted)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Pause")
                VStack(alignment: .leading, spacing: RTTheme.Spacing.xxs) {
                    Text("SCORE")
                        .font(RTTheme.Fonts.label(9))
                        .foregroundStyle(RTTheme.Colors.textFaded)
                    Text("\(gameState.score)")
                        .font(RTTheme.Fonts.headline(20))
                        .foregroundStyle(RTTheme.Colors.textPrimary)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: RTTheme.Spacing.xxs) {
                    Text("COINS")
                        .font(RTTheme.Fonts.label(9))
                        .foregroundStyle(RTTheme.Colors.textFaded)
                    HStack(spacing: RTTheme.Spacing.xs) {
                        Image(systemName: "bitcoinsign.circle")
                            .font(RTTheme.Fonts.callout(14))
                            .foregroundStyle(RTTheme.Colors.accentAmber)
                        Text("\(gameState.tapCoins)")
                            .font(RTTheme.Fonts.body(16))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                }
                VStack(alignment: .center, spacing: 0) {
                    HStack(spacing: RTTheme.Spacing.xxs) {
                        Text("\(gameState.multiplier)")
                            .font(RTTheme.Fonts.headline(18))
                            .foregroundStyle(RTTheme.Colors.blueStart)
                        Text("×")
                            .font(RTTheme.Fonts.body(14))
                            .foregroundStyle(RTTheme.Colors.blueStart.opacity(0.8))
                    }
                }
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: RTTheme.Spacing.sm) {
                        Text("\(gameState.combo)")
                            .font(RTTheme.Fonts.headline(20))
                            .foregroundStyle(comboColor)
                        if gameState.combo > 5 {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(comboColor)
                                .font(RTTheme.Fonts.callout(14))
                        }
                    }
                    Text("COMBO")
                        .font(RTTheme.Fonts.small(8))
                        .foregroundStyle(RTTheme.Colors.textFaded)
                }
            }
            .padding(.horizontal, RTTheme.Spacing.xxl)
            .padding(.vertical, RTTheme.Spacing.lg)
            .background(.ultraThinMaterial.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: RTTheme.Radius.overlay))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .padding(.horizontal, RTTheme.Spacing.md)
            .padding(.top, topSafe + RTTheme.Spacing.md)
            
            if gameState.revengeActive {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(RTTheme.Fonts.body(16))
                        .foregroundStyle(RTTheme.Colors.accentOrange)
                    Text("REVENGE MODE ACTIVE!")
                        .font(RTTheme.Fonts.body(14))
                        .foregroundStyle(RTTheme.Colors.accentOrange)
                    Image(systemName: "bolt.fill")
                        .font(RTTheme.Fonts.body(16))
                        .foregroundStyle(RTTheme.Colors.accentOrange)
                }
                .padding(.horizontal, RTTheme.Spacing.block)
                .padding(.vertical, RTTheme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                        .fill(RTTheme.Colors.accentOrange.opacity(0.2))
                        .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.button).stroke(RTTheme.Colors.accentOrange, lineWidth: 2))
                )
                .shadow(color: RTTheme.Colors.accentOrange.opacity(0.5), radius: 10)
                .padding(.horizontal)
                .padding(.top, RTTheme.Spacing.md)
                .transition(.scale.combined(with: .opacity))
            } else if gameState.canActivateRevenge() {
                Button(action: {
                    RTHaptics.impact()
                    scene?.activateRevengeFromButton()
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(RTTheme.Fonts.body(16))
                        Text("ACTIVATE REVENGE")
                            .font(RTTheme.Fonts.body(14))
                        Image(systemName: "bolt.fill")
                            .font(RTTheme.Fonts.body(16))
                    }
                    .foregroundStyle(RTTheme.Colors.blueStart)
                    .padding(.horizontal, RTTheme.Spacing.block)
                    .padding(.vertical, RTTheme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .fill(RTTheme.Colors.blueStart.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.button).stroke(RTTheme.Colors.blueStart, lineWidth: 2))
                    )
                    .shadow(color: RTTheme.Colors.blueStart.opacity(0.5), radius: 10)
                }
                .padding(.horizontal)
                .padding(.top, RTTheme.Spacing.md)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            Spacer()
        }
        }
    }

    private var comboColor: Color {
        if gameState.combo > 20 { return .purple }
        if gameState.combo > 10 { return .orange }
        if gameState.combo > 5 { return .yellow }
        return .white
    }
    
    private var judgementColor: Color {
        switch gameState.lastJudgement {
        case .perfect: return .yellow
        case .great: return .green
        case .good: return .cyan
        case .miss: return .red
        }
    }
    
    private var judgementScale: CGFloat {
        gameState.lastJudgement == .perfect ? 1.2 : 1.0
    }

    private var statusText: String {
        switch gameState.lastJudgement {
        case .perfect: return "Perfect"
        case .great: return "Great"
        case .good: return "Good"
        case .miss: return "Miss"
        }
    }
    
    private var resultsOverlay: some View {
        ResultsView(
            gameState: gameState,
            songId: selectedSong.id,
            difficulty: selectedDifficulty,
            onRestart: {
                let sizeToUse = safeSize(scene?.size ?? CGSize(width: 393, height: 852))
                scene?.stop()
                scene = nil
                gameState.reset()
                gameState.setSong(selectedSong)
                gameState.setDifficulty(selectedDifficulty)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let newScene = GameScene(size: sizeToUse)
                    newScene.scaleMode = .resizeFill
                    newScene.configure(song: selectedSong, difficulty: selectedDifficulty, gameState: gameState)
                    scene = newScene
                }
            },
            onExit: {
                scene?.stop()
                scene = nil
                gameState.reset()
                isPlaying = false
            },
            onContinue: {
                // Default: go to menu (same as onExit)
                scene?.stop()
                scene = nil
                gameState.reset()
                isPlaying = false
            }
        )
    }

    private func refreshAvailability(for song: SongMetadata) {
        if song.id == "user_beatmap" {
            availableDifficulties = Set(Difficulty.allCases)
            return
        }
        availableDifficulties = ChartLoader.availability(for: song)
        if availableDifficulties.isEmpty {
            availableDifficulties = [.medium]
        }
    }
}

// MARK: - Results View
struct ResultsView: View {
    let gameState: GameState
    let songId: String
    let difficulty: Difficulty
    let onRestart: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var multiplayerStore = MultiplayerStore.shared
    
    @State private var animateGrade = false
    @State private var animateStats = false
    @State private var didApplyXP = false
    @State private var xpResult: LevelUpResult?
    @State private var displayLevel: Int = 1
    @State private var displayProgress: Double = 0
    @State private var showChallengeSheet = false
    
    private var accuracy: Double {
        guard gameState.totalNotes > 0 else { return 0 }
        return Double(gameState.notesHit) / Double(gameState.totalNotes) * 100
    }
    
    private var grade: String {
        if accuracy >= 95 { return "S" }
        if accuracy >= 90 { return "A" }
        if accuracy >= 80 { return "B" }
        if accuracy >= 70 { return "C" }
        if accuracy >= 60 { return "D" }
        return "F"
    }
    
    private var gradeColor: Color {
        switch grade {
        case "S": return RTTheme.Colors.goldStart
        case "A": return RTTheme.Colors.successStart
        case "B": return RTTheme.Colors.blueStart
        case "C": return RTTheme.Colors.accentOrange
        case "D": return RTTheme.Colors.selectedRed
        default: return RTTheme.Colors.textDisabled
        }
    }

    private var gradeGlow: Color {
        gradeColor.opacity(0.6)
    }
    
    var body: some View {
        ZStack {
            resultsBackground
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: RTTheme.Spacing.block)
                    accountHeader
                    levelProgressSection
                    gradeSection
                    statsSection
                    Spacer()
                    actionButtons
                    gameCenterButtons
                }
            }
        }
        .padding(.horizontal, RTTheme.Spacing.medium)
        .padding(.bottom, RTTheme.Spacing.medium)
        .onAppear {
            withAnimation(RTTheme.Animation.emphasisEaseOut) {
                animateGrade = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + RTTheme.Animation.standard) {
                withAnimation(RTTheme.Animation.emphasisEaseOut) {
                    animateStats = true
                }
            }
            applyXPIfNeeded()
            Task { await MainActor.run { GameCenterManager.shared.submitResult(gcResult()) } }
            submitMultiplayerScoreIfNeeded()
        }
        .sheet(isPresented: $showChallengeSheet) {
            ChallengeFriendsSheet(result: gcResult())
        }
    }

    private func submitMultiplayerScoreIfNeeded() {
        guard multiplayerStore.isAuthenticated else { return }
        let accuracyValue = accuracy
        multiplayerStore.submitScore(
            trackId: songId,
            difficulty: difficulty,
            score: gameState.score,
            accuracy: accuracyValue,
            maxCombo: gameState.maxCombo
        )
    }

    private var accountHeader: some View {
        HStack(spacing: RTTheme.Spacing.md) {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(RTTheme.Colors.textSecondary)
            Text("\(displayName)  Lv.\(accountManager.state.level)")
                .font(RTTheme.Fonts.caption(12))
                .foregroundStyle(RTTheme.Colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, RTTheme.Spacing.block)
        .padding(.top, RTTheme.Spacing.md)
    }

    private var displayName: String {
        if accountManager.isSignedIn, let name = accountManager.state.username, !name.isEmpty {
            return name
        }
        return "Guest"
    }

    private var resultsBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    RTTheme.Colors.backgroundDarkStart,
                    RTTheme.Colors.backgroundDarkEnd
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(gradeGlow)
                .blur(radius: 80)
                .offset(x: -100, y: -100)

            Circle()
                .fill(RTTheme.Colors.blueStart.opacity(0.2))
                .blur(radius: 120)
                .offset(x: 150, y: 200)
        }
    }

    private var gradeSection: some View {
        VStack(spacing: RTTheme.Spacing.block) {
            Text("SONG COMPLETE!")
                .font(RTTheme.Fonts.title(32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RTTheme.Colors.blueStart, RTTheme.Colors.blueEnd, gradeColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: RTTheme.Colors.blueStart, radius: 15)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [gradeColor.opacity(0.3), gradeColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(gradeColor, lineWidth: 3))
                Text(grade)
                    .font(RTTheme.Fonts.title(100))
                    .foregroundStyle(gradeColor)
                    .shadow(color: gradeGlow, radius: 20)
            }
            .frame(height: 180)
            .padding(.vertical, RTTheme.Spacing.medium)
            .scaleEffect(animateGrade ? 1.0 : 0.8)
            .opacity(animateGrade ? 1.0 : 0.0)
        }
        .padding(.bottom, RTTheme.Spacing.large)
    }

    private var statsSection: some View {
        VStack(spacing: RTTheme.Spacing.block) {
            HStack(spacing: RTTheme.Spacing.block) {
                StatCard(label: "Score", value: "\(gameState.score)", icon: "star.fill", color: RTTheme.Colors.goldStart)
                StatCard(label: "Accuracy", value: String(format: "%.1f%%", accuracy), icon: "bullseye", color: RTTheme.Colors.successStart)
            }
            if gameState.lastCoinsEarned > 0 {
                HStack(spacing: RTTheme.Spacing.medium) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(RTTheme.Fonts.body(20))
                        .foregroundStyle(RTTheme.Colors.accentAmber)
                    Text("+\(gameState.lastCoinsEarned) Tap Coins")
                        .font(RTTheme.Fonts.body(18))
                        .foregroundStyle(RTTheme.Colors.accentAmber)
                }
                .padding(RTTheme.Spacing.xl)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                        .fill(RTTheme.Colors.accentAmber.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.button).stroke(RTTheme.Colors.accentAmber.opacity(0.5), lineWidth: 2))
                )
            }
            HStack(spacing: RTTheme.Spacing.block) {
                StatCard(label: "Max Combo", value: "\(gameState.maxCombo)", icon: "flame.fill", color: RTTheme.Colors.selectedRed)
                StatCard(label: "Notes Hit", value: "\(gameState.notesHit)/\(gameState.totalNotes)", icon: "checkmark.circle.fill", color: RTTheme.Colors.successStart)
            }
            if gameState.isNewPersonalBest {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(RTTheme.Fonts.body(20))
                        .foregroundStyle(RTTheme.Colors.accentAmber)
                    VStack(alignment: .leading, spacing: RTTheme.Spacing.xs) {
                        Text("NEW PERSONAL BEST!")
                            .font(RTTheme.Fonts.body(16))
                            .foregroundStyle(RTTheme.Colors.accentAmber)
                        Text("\(gameState.personalBest)")
                            .font(RTTheme.Fonts.headline(20))
                            .foregroundStyle(RTTheme.Colors.accentAmber)
                    }
                    Spacer()
                }
                .padding(RTTheme.Spacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                        .fill(RTTheme.Colors.accentAmber.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.button).stroke(RTTheme.Colors.accentAmber.opacity(0.5), lineWidth: 2))
                )
            } else {
                HStack {
                    Text("Personal Best")
                        .font(RTTheme.Fonts.body(16))
                        .foregroundStyle(RTTheme.Colors.textMuted)
                    Spacer()
                    Text("\(gameState.personalBest)")
                        .font(RTTheme.Fonts.headline(20))
                        .foregroundStyle(RTTheme.Colors.textPrimary)
                }
                .padding(RTTheme.Spacing.xxl)
                .background(RoundedRectangle(cornerRadius: RTTheme.Radius.button).fill(RTTheme.Colors.surfaceSubtle))
            }
        }
        .padding(RTTheme.Spacing.screen)
        .background(
            RoundedRectangle(cornerRadius: RTTheme.Radius.overlay)
                .fill(RTTheme.Colors.surfaceMuted)
                .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.overlay).stroke(RTTheme.Colors.surfaceStroke, lineWidth: 1))
        )
        .padding(.horizontal, RTTheme.Spacing.block)
        .offset(y: animateStats ? 0 : 30)
        .opacity(animateStats ? 1.0 : 0.0)
    }

    private var actionButtons: some View {
        HStack(spacing: RTTheme.Spacing.xxl) {
            RTActionButton(title: "CONTINUE", icon: "arrow.right.circle.fill", style: .gold) { RTHaptics.impact(); onContinue() }
            RTActionButton(title: "Retry", icon: "arrow.clockwise", style: .success) { RTHaptics.impact(); onRestart() }
            RTActionButton(title: "Menu", icon: "house.fill", style: .secondary) { RTHaptics.impact(); onExit() }
        }
        .padding(RTTheme.Spacing.block)
    }

    private var gameCenterButtons: some View {
        HStack(spacing: RTTheme.Spacing.lg) {
            RTSecondaryButton(title: "Leaderboards", icon: "list.number") {
                RTHaptics.impact()
                Task { await MainActor.run { GameCenterManager.shared.presentLeaderboards() } }
            }
            RTPrimaryButton(title: "Challenge Friends", icon: "person.2.wave.2") {
                RTHaptics.impact()
                showChallengeSheet = true
            }
        }
        .padding(.bottom, RTTheme.Spacing.block)
    }

    private var levelProgressSection: some View {
        VStack(alignment: .leading, spacing: RTTheme.Spacing.sm) {
            HStack(spacing: RTTheme.Spacing.sm) {
                LevelBadge(level: displayLevel)
                if let xpResult, !xpResult.rankName.isEmpty {
                    Text(xpResult.rankName)
                        .font(RTTheme.Fonts.caption(11))
                        .foregroundStyle(RTTheme.Colors.textMuted)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: RTTheme.Radius.small)
                        .fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: RTTheme.Radius.small)
                        .fill(RTTheme.Colors.accentOrange)
                        .frame(width: max(6, geo.size.width * CGFloat(min(max(displayProgress, 0), 1))))
                }
            }
            .frame(height: RTTheme.Spacing.medium)
            if let xpResult {
                Text("+\(xpResult.xpGained) XP")
                    .font(RTTheme.Fonts.caption(12))
                    .foregroundColor(.white.opacity(0.85))
                if xpResult.didLevelUp {
                    Text("Level up! · \(xpResult.rankName)")
                        .font(RTTheme.Fonts.caption(11))
                        .foregroundStyle(RTTheme.Colors.accentAmber)
                }
            }
            if let breakdown = xpResult?.breakdown {
                xpBreakdownView(breakdown: breakdown)
            }
        }
        .padding(RTTheme.Spacing.lg)
        .background(Color.black.opacity(0.25))
        .cornerRadius(RTTheme.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                .stroke(RTTheme.Colors.surfaceStrokeLight, lineWidth: 1)
        )
        .padding(.horizontal, RTTheme.Spacing.screen)
        .padding(.bottom, RTTheme.Spacing.md)
    }

    private func xpBreakdownView(breakdown: XPBreakdown) -> some View {
        VStack(alignment: .leading, spacing: RTTheme.Spacing.xxs) {
            xpBreakdownRow("Base", breakdown.base)
            if breakdown.accuracyBonus != 0 { xpBreakdownRow("Accuracy", breakdown.accuracyBonus) }
            if breakdown.comboBonus != 0 { xpBreakdownRow("Combo", breakdown.comboBonus) }
            if breakdown.lengthBonus != 0 { xpBreakdownRow("Length", breakdown.lengthBonus) }
            if breakdown.gradeBonus != 0 { xpBreakdownRow("Grade", breakdown.gradeBonus) }
            Divider().background(RTTheme.Colors.surfaceStroke).padding(.vertical, 2)
            HStack {
                Text("Total")
                    .font(RTTheme.Fonts.caption(12))
                    .foregroundStyle(RTTheme.Colors.textSecondary)
                Spacer()
                Text("+\(breakdown.total) XP")
                    .font(RTTheme.Fonts.body(12))
                    .foregroundStyle(RTTheme.Colors.accentAmber)
            }
        }
        .padding(.top, RTTheme.Spacing.sm)
    }

    private func xpBreakdownRow(_ label: String, _ value: Int64) -> some View {
        HStack {
            Text(label)
                .font(RTTheme.Fonts.caption(11))
                .foregroundStyle(RTTheme.Colors.textMuted)
            Spacer()
            Text(value >= 0 ? "+\(value)" : "\(value)")
                .font(RTTheme.Fonts.caption(11))
                .foregroundStyle(value >= 0 ? RTTheme.Colors.textSecondary : RTTheme.Colors.selectedRed)
        }
    }

    private func applyXPIfNeeded() {
        guard !didApplyXP else { return }
        didApplyXP = true
        let result = SongResult(
            score: gameState.score,
            maxScore: max(gameState.totalNotes, 1) * 1000,
            accuracyPercent: accuracy,
            maxCombo: gameState.maxCombo,
            misses: gameState.missedNotes,
            grade: grade,
            difficulty: mapDifficulty(gameState.difficulty),
            totalNotes: max(gameState.totalNotes, 0)
        )
        let output = gameState.awardXP(result: result)
        xpResult = output
        let thresholds = LevelingCurve.defaultThresholds
        let oldTotal = output.totalXP - output.xpGained
        let oldLevel = output.oldLevel
        displayLevel = oldLevel
        displayProgress = progress(totalXP: oldTotal, level: oldLevel, thresholds: thresholds)

            if output.didLevelUp {
            withAnimation(RTTheme.Animation.emphasisEaseOut) {
                displayProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                displayLevel = output.newLevel
                withAnimation(RTTheme.Animation.emphasisEaseOut) {
                    displayProgress = progress(totalXP: output.totalXP, level: output.newLevel, thresholds: thresholds)
                }
            }
        } else {
            withAnimation(.easeOut(duration: RTTheme.Animation.long)) {
                displayProgress = progress(totalXP: output.totalXP, level: output.newLevel, thresholds: thresholds)
            }
        }
    }

    private func progress(totalXP: Int64, level: Int, thresholds: [Int64]) -> Double {
        let prev = thresholds[min(level, LevelingCurve.maxLevel)]
        let next = thresholds[min(level + 1, LevelingCurve.maxLevel)]
        if next <= prev { return 1.0 }
        return Double(totalXP - prev) / Double(next - prev)
    }

    private func mapDifficulty(_ difficulty: Difficulty) -> SongDifficulty {
        switch difficulty {
        case .easy: return .easy
        case .medium: return .normal
        case .hard: return .hard
        case .extreme: return .expert
        }
    }

    private func gcResult() -> GCSongResult {
        GCSongResult(
            songId: gameState.songID,
            difficulty: gameState.difficulty.rawValue.lowercased(),
            score: gameState.score,
            accuracyPercent: accuracy,
            maxCombo: gameState.maxCombo,
            didFC: gameState.missedNotes == 0,
            timestamp: Date()
        )
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: RTTheme.Spacing.md) {
            Image(systemName: icon)
                .font(RTTheme.Fonts.body(24))
                .foregroundStyle(color)
            Text(label)
                .font(RTTheme.Fonts.caption(12))
                .foregroundStyle(RTTheme.Colors.textMuted)
            Text(value)
                .font(RTTheme.Fonts.headline(18))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(RTTheme.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                .fill(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.button).stroke(color.opacity(0.3), lineWidth: 1))
        )
    }
}
