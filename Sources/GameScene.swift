import SpriteKit
import SwiftUI
import CoreMotion
import UIKit
import QuartzCore

final class GameScene: SKScene {

    override init(size: CGSize) {
        super.init(size: safeSize(size))
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    weak var gameState: GameState?

    /// Layout-safe size; use for all node size assignments and layout math.
    private var effectiveSize: CGSize { safeSize(size) }

    private var chart: Chart = Chart.empty
    private var notes: [Note] = []
    private var noteLookup: [String: Note] = [:]
    private var nextNoteIndex: Int = 0
    private var activeNotes: [String: SKNode] = [:]
    private var notesContainer = SKNode()
    private var notePoolByLane: [[SKNode]] = []
    private var notePoolCapacityPerLane: Int = 64
    private var audio: GameAudioEngine!
    private var didBuildLanes: Bool = false
    /// True after buildOnce() has run; ensures we only build when size is valid and defer relayout on size change.
    private var didBuildScene: Bool = false
    private var errorLabelNode: SKLabelNode?
    private var particleCache: [String: SKEmitterNode] = [:]
    private var isPausedState: Bool = false
    private var song: SongMetadata!
    private var totalNotes: Int = 0
    var useNewMechanicsCore = true
    private var mechanicsCore: MechanicsCore?
    
    // Shake detection
    private let motionManager = CMMotionManager()
    private var lastShakeTime: TimeInterval = 0
    private let shakeDebounce: TimeInterval = 0.5
    private var shakeThreshold: Double = 1.8
    
    // Hold note tracking
    private var activeHolds: [String: (startTime: TimeInterval, lane: Int)] = [:]
    private var touchedLanes: Set<Int> = []

    private var songStartTime: TimeInterval?
    /// Wall-clock time when startMusic() was called; used for one authoritative song-time clock (audio + fallback).
    private var songStartWallTime: CFTimeInterval?
    private var startDelay: TimeInterval = 0.35
    /// If set (e.g. multiplayer sync), used instead of startDelay when starting music.
    var musicStartDelayOverride: TimeInterval?
    private let spawnLeadTime: Double = 2.8   // Increased for better visual feedback
    private let hitLineRatio: CGFloat = 0.25
    /// Padding above safe area bottom (home indicator) for the hit line / receptors.
    private let receptorPadding: CGFloat = 20
    private let baseNoteSpeed: CGFloat = 450   // Optimized for smooth gameplay at 60fps
    private var hitWindow: Double = 0.16
    private var perfectWindow: Double = 0.05
    private var greatWindow: Double = 0.08
    private var goodWindow: Double = 0.16
    private var noteSpeed: CGFloat = 450
    private var hitLineY: CGFloat = 200  // Calculated dynamically based on screen size
    private var judgementOffsetSec: Double = 0
    private var lastNoteEndTime: Double = 0
    private var laneColors: [SKColor] = []

    private var revengeOverlayNode: SKSpriteNode?
    private var laneBackgroundNode: SKSpriteNode?
    private var backgroundEmitters: [SKEmitterNode] = []
    private var hitLineNodes: [SKNode] = []
    private var laneGuideNodes: [SKNode] = []
    private var hitButtonNodes: [SKNode] = []
    private var hitButtonRects: [CGRect] = []
    private var touchLaneMap: [ObjectIdentifier: Int] = [:]
    private var latestJudgementTime: Double = 0
    private var pendingHoldLane: Int?
    private var pendingHoldTapTime: Double = 0
    private var pendingHoldStarted: Bool = false
    private var highwayGeometry = HighwayGeometry(topY: 0, bottomY: 0, topLeftX: 0, topRightX: 0, bottomLeftX: 0, bottomRightX: 0)

    // MARK: - Device-independent layout (safe area → playable rect)
    /// Safe area insets in points; set from SwiftUI (view/geo safe area). With scaleMode .resizeFill, 1 pt = 1 scene unit.
    var safeAreaInsets: UIEdgeInsets = .zero
    /// Playable region in scene coordinates (inset by safe area). Origin bottom-left; use for HUD and lane layout.
    private var playableRect: CGRect = .zero
    private var lastUpdateTime: TimeInterval?

    /// Gameplay lifecycle phase. Fail/completion evaluation and results only run when phase == .playing; results only after .ended.
    enum Phase {
        case loading   // Chart/audio loading
        case countdown // Chart loaded, waiting for start delay
        case playing   // Active gameplay; only now do we evaluate fail/completion
        case ended    // Song ended (completed or failed); safe to show results
    }
    private(set) var gamePhase: Phase = .loading

    private var chartLoading: Bool = false
    private var pendingMusicDelay: TimeInterval?
    private var didPrewarmAssets: Bool = false
    private var visualsDeferredUntil: TimeInterval?
    private var didFinalizeVisuals: Bool = false
    private var lastSettingsRevision: Int = -1
    private var cachedButtonSizeScale: CGFloat = 1.0
    private var cachedLeftHandedMode: Bool = false
    private var cachedNoteGlowEnabled: Bool = true
    private var cachedReduceFlashing: Bool = false
    private var cachedScreenShakeEnabled: Bool = true
    private var cachedBackgroundIntensity: BackgroundIntensity = .full
    private var cachedDisableBackgroundAnimations: Bool = false
    private var cachedColorblindPreset: ColorblindPreset = .normal
    private var cachedHighContrastNotes: Bool = false
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private var enablePerfLogging: Bool = true
    private var perfLastLogTime: TimeInterval?
    private var perfFrameCount: Int = 0
    private var perfDtSpikeCount: Int = 0

    // Debug timing overlay (toggle with triple-tap in top-left)
    static var showTimingDebugOverlay: Bool = false
    private var timingDebugNode: SKNode?
    private var timingDebugTapCount: Int = 0
    private var timingDebugLastTapTime: TimeInterval = 0
    private var timingDebugFPS: Double = 0
    private var timingDebugDtMs: Double = 0
    private var timingDebugFrameCount: Int = 0
    private var timingDebugFPSElapsed: TimeInterval = 0
    
    // Revenge mode animation
    private var revengeBackgroundNodes: [SKSpriteNode] = []
    private var revengeAnimationIndex: Int = 0
    private var isRevengeAnimating: Bool = false
    private let revengeBackgroundImages = [
        "revenge_bg_0.jpg",
        "revenge_bg_1.png",
        "revenge_bg_2.png",
        "revenge_bg_3.png"
    ]
    
    // TTR4-style UI elements
    private var comboLabel: SKLabelNode?
    private var multiplierLabel: SKLabelNode?
    private var laneGlowNodes: [SKSpriteNode] = []
    private var lastCombo: Int = 0
    private var lastMultiplier: Int = 1
    private var enableGameplayEmitters: Bool = false

    // Milestone thresholds (base tuned; combo and multiplier vary per difficulty)

    private func multiplierMilestones(for difficulty: Difficulty) -> [Int] {
        switch difficulty {
        case .easy:
            return [2, 4, 6]
        case .medium:
            return [3, 5, 8]
        case .hard:
            return [4, 6, 8]
        case .extreme:
            return [5, 7, 9]
        }
    }

    private func comboMilestones(for difficulty: Difficulty) -> [Int] {
        switch difficulty {
        case .easy:
            return [5, 10, 25, 50]
        case .medium:
            return [10, 25, 50, 100]
        case .hard:
            return [15, 30, 60, 120]
        case .extreme:
            return [20, 40, 80, 160]
        }
    }

    private func comboRepeatMilestone(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 50
        case .medium: return 100
        case .hard: return 150
        case .extreme: return 200
        }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        scaleMode = .resizeFill
        let camera = SKCameraNode()
        camera.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        addChild(camera)
        self.camera = camera
        // Camera is fixed; do not move it during gameplay. All lanes/background/notes use scene coordinates (0..<size).
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true

        ensureNotesContainer()
        TextureManager.shared.preloadForGame()
        hapticGenerator.prepare()
        applySettings(forceRebuild: true)
        applyFPSCap(to: view)

        if childNode(withName: "debugFallbackBG") == nil {
            let bg = SKSpriteNode(color: .darkGray, size: safeSize(size))
            bg.name = "debugFallbackBG"
            bg.zPosition = -10_000
            bg.position = CGPoint(x: effectiveSize.width * 0.5, y: effectiveSize.height * 0.5)
            addChild(bg)
        }

        if song == nil || chart.notes.isEmpty {
            showConfigurationErrorLabel()
            return
        }

        attemptBuildIfPossible()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if let bg = childNode(withName: "debugFallbackBG") as? SKSpriteNode {
            let s = safeSize(size)
            assertValidSize(s, context: "debugFallbackBG")
            bg.size = s
            bg.position = CGPoint(x: s.width * 0.5, y: s.height * 0.5)
        }
        if didBuildScene {
            clearLaneVisuals()
            didBuildScene = false
            didBuildLanes = false
        }
        attemptBuildIfPossible()
        if didBuildScene { relayout() }
    }

    private func showConfigurationErrorLabel() {
        guard errorLabelNode == nil else { return }
        let label = SKLabelNode(text: "No chart or song.\nCall configure() before presenting.")
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 18
        label.fontColor = .white
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = effectiveSize.width - 40
        label.position = CGPoint(x: effectiveSize.width * 0.5, y: effectiveSize.height * 0.5)
        label.zPosition = 10_000
        label.name = "configurationErrorLabel"
        addChild(label)
        errorLabelNode = label
    }

    private func attemptBuildIfPossible() {
        guard isFinitePositive(size.width), isFinitePositive(size.height) else { return }
        guard !didBuildScene else { return }
        guard song != nil, !chart.notes.isEmpty else { return }

        buildOnce()
        didBuildScene = true
    }

    private func buildOnce() {
        updatePlayableRect()
        updateHitLinePosition()
        updateHighwayGeometry()
        buildLanes()
        didBuildLanes = true
        rebuildNotePool()
        prewarmAssets()
        startMusicAfterDelay()
    }

    /// Repositions all HUD and lane nodes from playableRect. Call from didMove/didChangeSize and from SwiftUI when safe area changes.
    func layout() {
        let s = effectiveSize
        assertValidSize(s, context: "layout")
        updatePlayableRect()
        updateHitLinePosition()
        updateHighwayGeometry()
        guard didBuildScene else { return }
        // Rebuild hit line and buttons so they use new hitLineY
        for node in hitLineNodes {
            node.removeFromParent()
        }
        hitLineNodes.removeAll()
        buildHitLine()
        buildHitButtons()
        // Full-screen visuals stay centered; size unchanged
        laneBackgroundNode?.size = s
        laneBackgroundNode?.position = CGPoint(x: s.width * 0.5, y: s.height * 0.5)
        if let overlay = revengeOverlayNode {
            overlay.size = s
            overlay.position = CGPoint(x: s.width * 0.5, y: s.height * 0.5)
        }
        for node in laneGuideNodes {
            if let sprite = node as? SKSpriteNode, node.name == "laneVignette" {
                sprite.size = s
                sprite.position = CGPoint(x: s.width * 0.5, y: s.height * 0.5)
            }
        }
        // Stage base: anchor bottom to playableRect.minY (above home indicator)
        if let stage = childNode(withName: "stageBase") as? SKShapeNode {
            stage.position = CGPoint(x: 0, y: playableRect.minY)
        }
        // Lane guide lines and glows: span playable highway (hitLineY to topY)
        let highwayH = highwayGeometry.topY - highwayGeometry.bottomY
        let midY = (highwayGeometry.topY + highwayGeometry.bottomY) * 0.5
        for node in laneGuideNodes {
            if let sprite = node as? SKSpriteNode, node.name == "laneGuide" {
                sprite.size = CGSize(width: 2, height: max(1, highwayH))
                sprite.position = CGPoint(x: sprite.position.x, y: midY)
            }
        }
        for sprite in laneGlowNodes {
            let layout = laneLayout()
            let laneWidth = layout.laneWidth
            sprite.size = CGSize(width: max(1, laneWidth), height: max(1, highwayH))
            sprite.position = CGPoint(x: sprite.position.x, y: midY)
        }
    }

    private func relayout() {
        layout()
    }

    /// Start music only after visuals exist. Called from didMove(to:) after lanes/background are built.
    private func startMusicAfterDelay() {
        guard audio != nil else { return }
        let delay = musicStartDelayOverride ?? startDelay
        // authoritativeSongTime() expects songStartWallTime + startDelay = actual start time
        songStartWallTime = CACurrentMediaTime() + (delay - startDelay)
        visualsDeferredUntil = CACurrentMediaTime() + delay + 1.0
        mechanicsCore?.startTiming(
            rawPlaybackTimeProvider: { [weak self] in self?.audio.currentTime ?? 0 },
            audioStartTimestamp: songStartWallTime,
            audioStartDelaySeconds: delay
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.audio.play(after: 0)
            self.songStartTime = CACurrentMediaTime()
        }
    }

    private func applySettings(forceRebuild: Bool = false) {
        let settings = SettingsManager.shared
        if !forceRebuild && lastSettingsRevision == settings.settingsRevision {
            return
        }

        let newButtonSizeScale = CGFloat(settings.buttonSizeScale)
        let newLeftHandedMode = settings.leftHandedMode
        let newNoteGlowEnabled = settings.noteGlowEnabled
        let newReduceFlashing = settings.reduceFlashing
        let newScreenShakeEnabled = settings.screenShakeEnabled
        let newBackgroundIntensity = settings.backgroundIntensity
        let newDisableBackgroundAnimations = settings.disableBackgroundAnimations || settings.backgroundIntensity == .static
        let newColorblindPreset = settings.colorblindPreset
        let newHighContrastNotes = settings.highContrastNotes

        let layoutChanged = forceRebuild
            || cachedLeftHandedMode != newLeftHandedMode

        let visualsChanged = forceRebuild
            || cachedButtonSizeScale != newButtonSizeScale
            || cachedNoteGlowEnabled != newNoteGlowEnabled
            || cachedColorblindPreset != newColorblindPreset
            || cachedHighContrastNotes != newHighContrastNotes
            || cachedBackgroundIntensity != newBackgroundIntensity
            || cachedDisableBackgroundAnimations != newDisableBackgroundAnimations

        cachedButtonSizeScale = newButtonSizeScale
        cachedLeftHandedMode = newLeftHandedMode
        cachedNoteGlowEnabled = newNoteGlowEnabled
        cachedReduceFlashing = newReduceFlashing
        cachedScreenShakeEnabled = newScreenShakeEnabled
        cachedBackgroundIntensity = newBackgroundIntensity
        cachedDisableBackgroundAnimations = newDisableBackgroundAnimations
        cachedColorblindPreset = newColorblindPreset
        cachedHighContrastNotes = newHighContrastNotes

        noteSpeed = baseNoteSpeed * CGFloat(settings.noteSpeedMultiplier)
        judgementOffsetSec = Double(settings.audioOffsetMs) / 1000.0
        mechanicsCore?.globalOffsetSeconds = judgementOffsetSec
        perfectWindow = settings.hitWindowPreset.perfectMs / 1000.0
        greatWindow = settings.hitWindowPreset.greatMs / 1000.0
        goodWindow = settings.hitWindowPreset.goodMs / 1000.0
        hitWindow = goodWindow

        laneColors = laneColorsForSettings()
        applyBackgroundIntensity()
        updateBackgroundAnimationState()

        if layoutChanged || visualsChanged {
            clearLaneVisuals()
            didBuildLanes = false
        }

        if !cachedNoteGlowEnabled {
            for (_, node) in activeNotes {
                for child in node.children where child is SKEmitterNode {
                    child.removeFromParent()
                }
            }
        }

        audio.applySettings(settings)
        if let view = view {
            applyFPSCap(to: view)
        }
        lastSettingsRevision = settings.settingsRevision
    }

    private func applyFPSCap(to view: SKView) {
        let settings = SettingsManager.shared
        switch settings.fpsCap {
        case .auto:
            view.preferredFramesPerSecond = 120
        case .fps60:
            view.preferredFramesPerSecond = 60
        case .fps120:
            view.preferredFramesPerSecond = 120
        case .unlimited:
            view.preferredFramesPerSecond = 0
        }
    }

    private func laneColorsForSettings() -> [SKColor] {
        let settings = SettingsManager.shared
        let base: [SKColor]
        switch settings.colorblindPreset {
        case .normal:
            base = [
                SKColor(red: 0.4, green: 0.65, blue: 0.75, alpha: 1),
                SKColor(red: 0.45, green: 0.75, blue: 0.55, alpha: 1),
                SKColor(red: 0.85, green: 0.7, blue: 0.4, alpha: 1),
                SKColor(red: 0.85, green: 0.5, blue: 0.65, alpha: 1)
            ]
        case .deuteranopia:
            base = [
                SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1),
                SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1),
                SKColor(red: 0.5, green: 0.5, blue: 0.9, alpha: 1),
                SKColor(red: 0.9, green: 0.4, blue: 0.5, alpha: 1)
            ]
        case .protanopia:
            base = [
                SKColor(red: 0.2, green: 0.7, blue: 0.8, alpha: 1),
                SKColor(red: 0.9, green: 0.65, blue: 0.25, alpha: 1),
                SKColor(red: 0.6, green: 0.55, blue: 0.9, alpha: 1),
                SKColor(red: 0.85, green: 0.5, blue: 0.7, alpha: 1)
            ]
        case .tritanopia:
            base = [
                SKColor(red: 0.2, green: 0.7, blue: 0.5, alpha: 1),
                SKColor(red: 0.9, green: 0.55, blue: 0.25, alpha: 1),
                SKColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1),
                SKColor(red: 0.85, green: 0.35, blue: 0.75, alpha: 1)
            ]
        }

        if settings.highContrastNotes {
            return base.map { $0.withAlphaComponent(1.0) }
        }
        return base
    }

    private func applyBackgroundIntensity() {
        let settings = SettingsManager.shared
        let alpha: CGFloat
        switch settings.backgroundIntensity {
        case .full: alpha = 1.0
        case .dim: alpha = 0.55
        case .static: alpha = 1.0
        }
        laneBackgroundNode?.alpha = alpha
        for node in revengeBackgroundNodes where node.alpha > 0.0 {
            node.alpha = alpha
        }
    }

    private func updateBackgroundAnimationState() {
        let settings = SettingsManager.shared
        let shouldDisable = settings.disableBackgroundAnimations || settings.backgroundIntensity == .static
        if shouldDisable {
            for emitter in backgroundEmitters {
                emitter.particleBirthRate = 0
            }
            isRevengeAnimating = false
        } else {
            for emitter in backgroundEmitters {
                if emitter.particleBirthRate == 0 {
                    emitter.particleBirthRate = 35
                }
            }
        }
    }

    private func clearLaneVisuals() {
        for node in laneGuideNodes {
            node.removeFromParent()
        }
        laneGuideNodes.removeAll()

        for node in hitLineNodes {
            node.removeFromParent()
        }
        hitLineNodes.removeAll()

        for node in hitButtonNodes {
            node.removeFromParent()
        }
        hitButtonNodes.removeAll()
        hitButtonRects.removeAll()

        for node in laneGlowNodes {
            node.removeFromParent()
        }
        laneGlowNodes.removeAll()

        for emitter in backgroundEmitters {
            emitter.removeFromParent()
        }
        backgroundEmitters.removeAll()

        laneBackgroundNode?.removeFromParent()
        laneBackgroundNode = nil

        for node in revengeBackgroundNodes {
            node.removeFromParent()
        }
        revengeBackgroundNodes.removeAll()
        isRevengeAnimating = false
    }

    private func displayLaneIndex(for logicalLane: Int) -> Int {
        cachedLeftHandedMode ? (chart.lanes - 1 - logicalLane) : logicalLane
    }

    private func logicalLaneIndex(for displayLane: Int) -> Int {
        cachedLeftHandedMode ? (chart.lanes - 1 - displayLane) : displayLane
    }

    private func laneLayout() -> (laneWidth: CGFloat, laneStartX: CGFloat, laneCenters: [CGFloat]) {
        let laneCount = max(chart.lanes, 1)
        let w = safePositive(effectiveSize.width, fallback: 1)
        let laneWidth = w / CGFloat(laneCount)
        let laneStartX: CGFloat = 0
        let laneCenters = (0..<laneCount).map { lane in
            laneStartX + laneWidth * CGFloat(lane) + laneWidth * 0.5
        }
        return (laneWidth, laneStartX, laneCenters)
    }


    private func hitLaneIndex(for location: CGPoint) -> Int? {
        for (index, rect) in hitButtonRects.enumerated() {
            if rect.contains(location) {
                return index
            }
        }
        return nil
    }

    /// Required configuration before presentation. Loads chart and audio for the given song; do not present without calling this.
    func configure(song: SongMetadata, difficulty: Difficulty, gameState: GameState) {
        gamePhase = .loading
        gameState.reset()
        self.song = song
        self.gameState = gameState
        judgementOffsetSec = Double(SettingsManager.shared.audioOffsetMs) / 1000.0

        let result: (chart: Chart, notes: [Note], lastNoteEndTime: Double)
        if song.id == "user_beatmap", let beatmap = gameState.customBeatmap {
            let adaptedNotes = BeatmapAdapter.toNotes(beatmap)
            let loadedChart = Chart(
                version: 1,
                difficulty: difficulty,
                songName: song.title,
                bpm: song.bpm,
                offset: 0,
                lanes: beatmap.lanes,
                notes: adaptedNotes
            )
            let lastEnd = adaptedNotes.map { $0.time + ($0.duration ?? 0) }.max() ?? 0
            result = (loadedChart, adaptedNotes, lastEnd)
        } else {
            let loadResult = ChartLoader.loadChart(for: song, difficulty: difficulty)
            let sortedNotes = loadResult.chart.notes.sorted { $0.time < $1.time }
            let lastEnd = sortedNotes.map { $0.time + ($0.duration ?? 0) }.max() ?? 0
            result = (loadResult.chart, sortedNotes, lastEnd)
            if loadResult.wasFallback {
                gameState.difficulty = loadResult.usedDifficulty
            }
        }

        self.chart = result.chart
        self.notes = result.notes
        self.noteLookup = Dictionary(uniqueKeysWithValues: result.notes.map { ($0.id, $0) })
        self.totalNotes = result.notes.count
        self.lastNoteEndTime = result.lastNoteEndTime

        nextNoteIndex = 0
        activeNotes.removeAll()
        activeHolds.removeAll()
        songStartTime = nil
        songStartWallTime = nil

        if audio != nil {
            audio.stop()
        }
        audio = GameAudioEngine(song: song)
        audio.applySettings(SettingsManager.shared)

        chartLoading = false
        didBuildLanes = false
        didFinalizeVisuals = false
        gameState.totalNotes = totalNotes
        gamePhase = .countdown

        if useNewMechanicsCore && chart.lanes == 4 {
            let core = MechanicsCore()
            core.globalOffsetSeconds = judgementOffsetSec
            core.spawnLeadSeconds = 2.0
            core.maxSpawnPerUpdate = 2
            core.configureChartNotes(fromExistingNotes: notes, bpm: chart.bpm, offsetSeconds: chart.offset)
            core.onSpawnNote = { [weak self] data in
                guard let self, let note = data.sourceNote else { return nil }
                return self.spawnNoteNode(note)
            }
            core.onHitNote = { [weak self] data, _, grade in
                self?.handleMechanicsHit(noteData: data, grade: grade)
            }
            core.onMissNote = { [weak self] data, _ in
                self?.handleMechanicsMiss(noteData: data)
            }
            mechanicsCore = core
        } else {
            mechanicsCore = nil
        }
    }

    func setSong(_ song: SongMetadata) {
        self.song = song
        if audio != nil {
            audio.stop()
        }
        audio = GameAudioEngine(song: song)
        audio.applySettings(SettingsManager.shared)
        chartLoading = false
        pendingMusicDelay = nil
    }

    func start() {
        gamePhase = .loading
        removeAllChildren()
        ensureNotesContainer()
        audio.stop()
        audio.applySettings(SettingsManager.shared)
        prewarmAssets()
        
        // Reset revenge animation
        revengeBackgroundNodes.removeAll()
        isRevengeAnimating = false
        revengeAnimationIndex = 0
        
        // Reset game state FIRST before loading chart
        gameState?.reset()
        chartLoading = false
        pendingMusicDelay = nil
        
        let requestedDifficulty = gameState?.difficulty ?? .medium
        if song.id == "user_beatmap", let beatmap = gameState?.customBeatmap {
            let adaptedNotes = BeatmapAdapter.toNotes(beatmap)
            let loadedChart = Chart(
                version: 1,
                difficulty: requestedDifficulty,
                songName: song.title,
                bpm: song.bpm,
                offset: 0,
                lanes: beatmap.lanes,
                notes: adaptedNotes
            )
            applyLoadedChart(requestedDifficulty: requestedDifficulty, chart: loadedChart, notes: adaptedNotes, loadResult: nil)
        } else {
            chartLoading = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let loadResult = ChartLoader.loadChart(for: self.song, difficulty: requestedDifficulty)
                let loadedNotes = loadResult.chart.notes.sorted { $0.time < $1.time }
                DispatchQueue.main.async {
                    self.applyLoadedChart(
                        requestedDifficulty: requestedDifficulty,
                        chart: loadResult.chart,
                        notes: loadedNotes,
                        loadResult: loadResult
                    )
                }
            }
            return
        }
    }
    
    private func startShakeDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.processShakeDetection(data.acceleration)
        }
    }
    
    private func processShakeDetection(_ acceleration: CMAcceleration) {
        let totalAcceleration = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )
        
        // Detect shake when acceleration exceeds threshold
        if totalAcceleration > shakeThreshold {
            let now = Date().timeIntervalSince1970
            if now - lastShakeTime > shakeDebounce {
                lastShakeTime = now
                handleShakeDetected()
            }
        }
    }
    
    private func handleShakeDetected() {
        guard songStartTime != nil else { return }
        let songTime = latestJudgementTime
        
        // Find all active shake notes near current time
        // PERF: Per-frame allocation (filter) during gameplay.
        let candidates = notes.filter {
            $0.type == .shake &&
            activeNotes[$0.id] != nil &&
            abs($0.time - songTime) <= hitWindow
        }
        
        // Register the closest shake note
        if let target = candidates.min(by: {
            abs($0.time - songTime) < abs($1.time - songTime)
        }) {
            let delta = abs(target.time - songTime)
            let judgement = getJudgement(for: delta)
            register(judgement: judgement, for: target)
            
            // Activate revenge mode if conditions met
            gameState?.activateRevengeMode(currentTime: songTime)
        }
    }

    private func applyLoadedChart(
        requestedDifficulty: Difficulty,
        chart: Chart,
        notes: [Note],
        loadResult: ChartLoader.LoadResult?
    ) {
        self.chart = chart
        if let loadResult, loadResult.wasFallback {
            gameState?.difficulty = loadResult.usedDifficulty
            debugLog("⚠️ Requested difficulty \(requestedDifficulty.rawValue) missing, using \(loadResult.usedDifficulty.rawValue) from \(loadResult.fileName)")
        }
        self.notes = notes
        noteLookup = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        lastNoteEndTime = notes.map { $0.time + ($0.duration ?? 0) }.max() ?? 0
        nextNoteIndex = 0
        recycleAllActiveNotes()
        activeHolds.removeAll()
        songStartTime = nil
        latestSongTime = 0
        TextureManager.shared.preloadForGame()
        rebuildNotePool()
        lastUpdateTime = nil
        didBuildLanes = false
        didFinalizeVisuals = false
        visualsDeferredUntil = nil
        isPausedState = false
        gameState?.totalNotes = notes.count
        lastCombo = 0
        lastMultiplier = 1

        if useNewMechanicsCore && chart.lanes == 4 {
            let core = MechanicsCore()
            core.globalOffsetSeconds = judgementOffsetSec
            core.spawnLeadSeconds = 2.0
            core.maxSpawnPerUpdate = 2
            core.configureChartNotes(fromExistingNotes: notes, bpm: chart.bpm, offsetSeconds: chart.offset)
            core.onSpawnNote = { [weak self] data in
                guard let self, let note = data.sourceNote else { return nil }
                return self.spawnNoteNode(note)
            }
            core.onHitNote = { [weak self] data, _, grade in
                self?.handleMechanicsHit(noteData: data, grade: grade)
            }
            core.onMissNote = { [weak self] data, _ in
                self?.handleMechanicsMiss(noteData: data)
            }
            mechanicsCore = core
        } else {
            mechanicsCore = nil
        }

        chartLoading = false
        gamePhase = .countdown
        if let pendingMusicDelay {
            self.pendingMusicDelay = nil
            startMusic(after: pendingMusicDelay)
        }

        debugLog("Game started - Loaded \(notes.count) notes from chart")
        debugLog("Chart: \(chart.songName), BPM: \(chart.bpm), Lanes: \(chart.lanes)")
    }

    private func finalizeDeferredVisuals() {
        guard !didFinalizeVisuals else { return }
        didFinalizeVisuals = true
        if !cachedDisableBackgroundAnimations {
            addStarBursts()
        }
        buildLaneGuides()
        buildLaneGlows()
    }

    // Manual revenge activation (button)
    func activateRevengeFromButton() {
        guard let gameState else { return }
        guard gameState.canActivateRevenge() else { return }
        gameState.activateRevengeMode(currentTime: latestJudgementTime)
    }
    
    func startMusic(after delay: TimeInterval? = nil) {
        // Start music and align song timeline to the same delay. One authoritative clock: audio.currentTime + offset.
        let effectiveDelay = max(0, delay ?? startDelay)
        if chartLoading {
            pendingMusicDelay = effectiveDelay
            return
        }
        startDelay = effectiveDelay
        if audio.isReady {
            songStartWallTime = CACurrentMediaTime()
            audio.play(after: effectiveDelay)
            visualsDeferredUntil = CACurrentMediaTime() + effectiveDelay + 1.0
            mechanicsCore?.startTiming(
                rawPlaybackTimeProvider: { [weak self] in
                    self?.audio.currentTime ?? 0
                },
                audioStartTimestamp: songStartWallTime,
                audioStartDelaySeconds: effectiveDelay
            )
            songStartTime = nil  // Set on first update() so guards pass
        } else {
            debugLog("Audio not ready; skipping play")
        }
    }
    
    func pause() {
        isPausedState = true
        isPaused = true
        audio?.pause()
    }
    
    func resume() {
        isPausedState = false
        isPaused = false
        lastUpdateTime = nil
        audio?.resume()
    }
    
    func stop() {
        gamePhase = .loading
        audio?.stop()
        removeAllChildren()
        motionManager.stopAccelerometerUpdates()

        // Aggressively clear all state and references
        notes.removeAll()
        noteLookup.removeAll()
        recycleAllActiveNotes()
        activeHolds.removeAll()
        touchedLanes.removeAll()
        touchLaneMap.removeAll()
        revengeBackgroundNodes.removeAll()
        // Do not assign a new Chart; just clear state
        songStartTime = nil
        songStartWallTime = nil
        latestSongTime = 0
        lastUpdateTime = nil
        chartLoading = false
        pendingMusicDelay = nil
        visualsDeferredUntil = nil
        didFinalizeVisuals = false
        didBuildLanes = false
        didBuildScene = false
        isPausedState = false
        lastCombo = 0
        lastMultiplier = 1
        isRevengeAnimating = false
        revengeAnimationIndex = 0
        laneBackgroundNode = nil
        comboLabel = nil
        multiplierLabel = nil
        laneGlowNodes.removeAll()
        mechanicsCore = nil
        timingDebugNode?.removeFromParent()
        timingDebugNode = nil
    }

    /// Single authoritative song time (seconds). Uses audio playback position + offset; fallback before playback starts. Prevents drift over long songs.
    private func authoritativeSongTime() -> Double {
        guard let wall = songStartWallTime else { return 0 }
        let now = CACurrentMediaTime()
        if now < wall + startDelay {
            return 0
        }
        return max(0, audio.currentTime) + judgementOffsetSec
    }

    private func buildLanes() {
        // Add animated neon background
        addAnimatedBackground()

        // addSpotlights()  // Removed: transparent triangles
        // Star bursts deferred to reduce start hitch.
        addStageBase()
        
        // Add visual lane separators
        buildLaneGuides()
        
        // Build hit button regions for strict lane input
        buildHitButtons()
        updateHighwayGeometry()
        
        // Removed translucent lane overlays - using background images instead
    }

    /// Updates playableRect from scene size and safeAreaInsets. With .resizeFill, insets map 1:1 to scene units.
    private func updatePlayableRect() {
        let w = safePositive(size.width, fallback: 1)
        let h = safePositive(size.height, fallback: 1)
        playableRect = CGRect(
            x: safeAreaInsets.left,
            y: safeAreaInsets.bottom,
            width: max(1, w - safeAreaInsets.left - safeAreaInsets.right),
            height: max(1, h - safeAreaInsets.top - safeAreaInsets.bottom)
        )
    }

    /// Hit line sits above home indicator (playableRect.minY) with padding.
    private func updateHitLinePosition() {
        let h = playableRect.height
        guard h > 0 else { return }
        hitLineY = playableRect.minY + h * hitLineRatio
        hitLineY = max(hitLineY, playableRect.minY + receptorPadding)
    }

    private func updateHighwayGeometry() {
        let w = safePositive(effectiveSize.width, fallback: 1)
        let spawnY = playableRect.maxY + 40
        let bottomY = hitLineY
        var bottomLeftX: CGFloat = 0
        var bottomRightX: CGFloat = w
        if let first = hitButtonRects.first, let last = hitButtonRects.last {
            bottomLeftX = first.minX
            bottomRightX = last.maxX
        } else {
            let layout = laneLayout()
            bottomLeftX = layout.laneStartX
            bottomRightX = layout.laneStartX + layout.laneWidth * CGFloat(chart.lanes)
        }
        let bottomWidth = max(bottomRightX - bottomLeftX, 1)
        let topWidth = bottomWidth * 0.55
        let centerX = (bottomLeftX + bottomRightX) * 0.5
        let topLeftX = centerX - topWidth * 0.5
        let topRightX = centerX + topWidth * 0.5
        highwayGeometry = HighwayGeometry(
            topY: spawnY,
            bottomY: bottomY,
            topLeftX: topLeftX,
            topRightX: topRightX,
            bottomLeftX: bottomLeftX,
            bottomRightX: bottomRightX
        )
    }

    private func ensureNotesContainer() {
        if notesContainer.parent == nil {
            notesContainer.name = "notesContainer"
            notesContainer.zPosition = 5
            addChild(notesContainer)
        }
    }

    private func rebuildNotePool() {
        ensureNotesContainer()
        notesContainer.removeAllChildren()
        notePoolByLane = Array(repeating: [], count: max(chart.lanes, 1))
        if laneColors.isEmpty {
            laneColors = laneColorsForSettings()
        }
        let noteRadius: CGFloat = 30
        for lane in 0..<chart.lanes {
            let displayLane = displayLaneIndex(for: lane)
            for _ in 0..<notePoolCapacityPerLane {
                let dummy = Note(time: 0, lane: lane, type: .tap)
                let node = createNoteNode(for: dummy, displayLane: displayLane, noteRadius: noteRadius)
                node.isHidden = true
                node.position = CGPoint(x: -1000, y: -1000)
                setNodeDisplayLane(node, displayLane)
                notesContainer.addChild(node)
                if displayLane < notePoolByLane.count {
                    notePoolByLane[displayLane].append(node)
                }
            }
        }
        debugLog("Note pool preallocated: \(notePoolCapacityPerLane) per lane")
    }

    private func setNodeDisplayLane(_ node: SKNode, _ displayLane: Int) {
        if node.userData == nil {
            node.userData = NSMutableDictionary()
        }
        node.userData?["displayLane"] = displayLane
    }

    private func dequeuePooledNoteNode(displayLane: Int, noteRadius: CGFloat, note: Note) -> SKNode {
        if displayLane < notePoolByLane.count, let node = notePoolByLane[displayLane].popLast() {
            node.removeAllActions()
            node.alpha = 1.0
            node.setScale(1.0)
            node.zRotation = 0
            node.isHidden = false
            node.childNode(withName: "holdTail")?.removeFromParent()
            setNodeDisplayLane(node, displayLane)
            if node.parent !== notesContainer {
                node.removeFromParent()
                notesContainer.addChild(node)
            }
            return node
        }
            debugLog("⚠️ Note pool exhausted for lane \(displayLane)")
        let node = createNoteNode(for: note, displayLane: displayLane, noteRadius: noteRadius)
        node.isHidden = false
        setNodeDisplayLane(node, displayLane)
        if node.parent !== notesContainer {
            notesContainer.addChild(node)
        }
        return node
    }

    private func recycleNoteNode(_ node: SKNode) {
        node.removeAllActions()
        node.isHidden = true
        node.alpha = 1.0
        node.setScale(1.0)
        node.zRotation = 0
        node.childNode(withName: "holdTail")?.removeFromParent()
        node.position = CGPoint(x: -1000, y: -1000)
        let displayLane = node.userData?["displayLane"] as? Int ?? 0
        if displayLane < notePoolByLane.count {
            notePoolByLane[displayLane].append(node)
        }
    }

    private func recycleAllActiveNotes() {
        for (_, node) in activeNotes {
            recycleNoteNode(node)
        }
        activeNotes.removeAll()
    }
    
    private func createGradientTexture() -> SKTexture {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor(red: 0.02, green: 0.02, blue: 0.10, alpha: 1.0).cgColor,
                         UIColor(red: 0.05, green: 0.07, blue: 0.25, alpha: 1.0).cgColor,
                         UIColor(red: 0.10, green: 0.18, blue: 0.45, alpha: 1.0).cgColor,
                         UIColor(red: 0.16, green: 0.07, blue: 0.30, alpha: 1.0).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0.0, 0.35, 0.65, 1.0])!
            context.cgContext.drawLinearGradient(gradient,
                                                start: CGPoint(x: 0, y: 0),
                                                end: CGPoint(x: 0, y: size.height),
                                                options: [])
        }
        return SKTexture(image: image)
    }

    private func createSparkTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
        }
        return SKTexture(image: image)
    }

    private func prewarmAssets() {
        guard !didPrewarmAssets else { return }
        didPrewarmAssets = true
        TextureManager.shared.preloadForGame()
    }

    private func addAnimatedBackground() {
        // Add neon lane background with gameplay image based on lane count
        let backgroundName = chart.lanes == 4 ? "gameplay_background_4lane" : "gameplay_background"
        let s = effectiveSize
        let centerY = playableRect.midY

        if let bgTexture = TextureManager.shared.texture(named: backgroundName) {
            let bgSprite = SKSpriteNode(texture: bgTexture)
            bgSprite.position = CGPoint(x: s.width * 0.5, y: centerY)
            bgSprite.size = safeSize(s)
            assertValidSize(bgSprite.size, context: "laneBackground")
            bgSprite.zPosition = -10
            bgSprite.name = "laneBackground"
            addChild(bgSprite)
            laneBackgroundNode = bgSprite
            applyBackgroundIntensity()
            debugLog("Loaded \(backgroundName) for \(chart.lanes) lanes")
        } else if let bgImage = UIImage(named: backgroundName) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: backgroundName, ofType: "png") ?? "") {
            let bgSprite = SKSpriteNode(texture: SKTexture(image: bgImage))
            bgSprite.position = CGPoint(x: s.width * 0.5, y: centerY)
            bgSprite.size = safeSize(s)
            assertValidSize(bgSprite.size, context: "laneBackground")
            bgSprite.zPosition = -10
            bgSprite.name = "laneBackground"
            addChild(bgSprite)
            laneBackgroundNode = bgSprite
            applyBackgroundIntensity()
            debugLog("Loaded \(backgroundName) for \(chart.lanes) lanes")
        } else {
            debugLog("Warning: Could not load \(backgroundName).png")
        }
    }

    private func loadTexture(named name: String) -> SKTexture? {
        // PERF: SKTexture load path for runtime texture fetches.
        if let image = UIImage(named: name) {
            return SKTexture(image: image)
        }
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return SKTexture(image: image)
        }
        return nil
    }

    private func addSpotlights() {
        let spotlightColors: [SKColor] = [
            SKColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 0.35),
            SKColor(red: 0.35, green: 0.80, blue: 1.0, alpha: 0.30),
            SKColor(red: 1.00, green: 0.65, blue: 0.35, alpha: 0.32)
        ]

        let s = effectiveSize
        let centerY = s.height * 0.65
        let height: CGFloat = s.height * 0.9
        let width: CGFloat = s.width * 0.22
        let xPositions: [CGFloat] = [s.width * 0.2, s.width * 0.5, s.width * 0.8]

        for (index, x) in xPositions.enumerated() {
            let color = spotlightColors[index % spotlightColors.count]
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: s.height))
            path.addLine(to: CGPoint(x: x - width * 0.5, y: centerY - height * 0.3))
            path.addLine(to: CGPoint(x: x + width * 0.5, y: centerY - height * 0.3))
            path.closeSubpath()

            let cone = SKShapeNode(path: path)
            cone.fillColor = color
            cone.strokeColor = .clear
            cone.zPosition = 1
            cone.blendMode = .add
            addChild(cone)
        }
    }

    private func addStarBursts() {
        guard enableGameplayEmitters else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = TextureManager.shared.texture(named: "spark") ?? createSparkTexture()
        emitter.particleColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBirthRate = 35
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 4
        emitter.particleLifetimeRange = 2
        emitter.particleSpeed = 40
        emitter.particleSpeedRange = 30
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -0.2
        emitter.particleScale = 0.35
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.05
        let s = effectiveSize
        emitter.position = CGPoint(x: s.width * 0.5, y: s.height * 0.55)
        emitter.particlePositionRange = CGVector(dx: safePositive(s.width * 0.7, fallback: 1), dy: safePositive(s.height * 0.4, fallback: 1))
        emitter.zPosition = 2
        emitter.particleBlendMode = SKBlendMode.add
        addChild(emitter)
        backgroundEmitters.append(emitter)
    }

    private func addStageBase() {
        let stageHeight: CGFloat = 90
        let w = safePositive(effectiveSize.width, fallback: 1)
        let stage = SKShapeNode(rect: CGRect(x: 0, y: 0, width: w, height: stageHeight))
        stage.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        stage.strokeColor = SKColor.white.withAlphaComponent(0.08)
        stage.lineWidth = 2
        stage.zPosition = 3
        stage.name = "stageBase"
        stage.position = CGPoint(x: 0, y: playableRect.minY)
        addChild(stage)
        laneGuideNodes.append(stage)

        // Simple crowd silhouette using repeating arcs
        let crowd = SKShapeNode()
        let path = CGMutablePath()
        let bumps = Int(safePositive(effectiveSize.width, fallback: 1) / 20)
        for i in 0...bumps {
            let x = CGFloat(i) * 20
            let y: CGFloat = stageHeight * 0.4 + CGFloat.random(in: -6...6)
            path.addArc(center: CGPoint(x: x, y: y), radius: 12, startAngle: 0, endAngle: .pi, clockwise: false)
        }
        crowd.path = path
        crowd.fillColor = SKColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.65)
        crowd.strokeColor = .clear
        crowd.zPosition = 3.5
        crowd.name = "stageCrowd"
        addChild(crowd)
        laneGuideNodes.append(crowd)
    }

    private func buildLaneGuides() {
        let layout = laneLayout()
        let laneCenters = layout.laneCenters
        let lineColor = SKColor(red: 0.5, green: 0.5, blue: 0.7, alpha: 0.15)
        let lineTexture = TextureManager.shared.solidColorTexture(color: lineColor)

        let lineH = max(1, highwayGeometry.topY - highwayGeometry.bottomY)
        let midY = (highwayGeometry.topY + highwayGeometry.bottomY) * 0.5
        for lane in 0..<chart.lanes {
            if lane < chart.lanes - 1 {
                let x = (laneCenters[lane] + laneCenters[lane + 1]) / 2
                let line = SKSpriteNode(texture: lineTexture)
                line.size = safeSize(CGSize(width: 2, height: lineH))
                line.position = CGPoint(x: x, y: midY)
                line.zPosition = 1
                line.name = "laneGuide"
                addChild(line)
                laneGuideNodes.append(line)
            }
        }
        
        let s = effectiveSize
        let vignetteTexture = TextureManager.shared.solidColorTexture(color: SKColor.black.withAlphaComponent(0.22))
        let vignette = SKSpriteNode(texture: vignetteTexture)
        vignette.size = safeSize(s)
        assertValidSize(vignette.size, context: "laneVignette")
        vignette.position = CGPoint(x: s.width * 0.5, y: s.height * 0.5)
        vignette.zPosition = 4
        vignette.name = "laneVignette"
        addChild(vignette)
        laneGuideNodes.append(vignette)
    }
    
    private func buildLaneGlows() {
        laneGlowNodes.removeAll()
        guard cachedNoteGlowEnabled else { return }
        let layout = laneLayout()
        let laneWidth = layout.laneWidth
        let laneCenters = layout.laneCenters

        let lineH = max(1, highwayGeometry.topY - highwayGeometry.bottomY)
        let midY = (highwayGeometry.topY + highwayGeometry.bottomY) * 0.5
        for lane in 0..<chart.lanes {
            let centerX = laneCenters[lane]
            let glowColor = laneColors[lane % laneColors.count]
            let glowTexture = TextureManager.shared.solidColorTexture(color: glowColor)
            let glow = SKSpriteNode(texture: glowTexture)
            glow.size = safeSize(CGSize(width: safePositive(laneWidth, fallback: 1), height: lineH))
            glow.position = CGPoint(x: centerX, y: midY)
            glow.alpha = 0.0
            glow.zPosition = 2
            glow.blendMode = .add
            glow.name = "laneGlow"
            addChild(glow)
            laneGlowNodes.append(glow)
        }
    }
    
    private func buildHitLine() {
        // Create hit targets matching note lanes
        guard chart.lanes > 0 else { return }
        let layout = laneLayout()
        let laneWidth = layout.laneWidth
        let laneStartX = layout.laneStartX
        for lane in 0..<chart.lanes {
            let centerX = laneStartX + CGFloat(lane) * laneWidth + laneWidth * 0.5
            let circle = SKShapeNode(circleOfRadius: 35 * cachedButtonSizeScale)
            circle.position = CGPoint(x: centerX, y: hitLineY)
            circle.fillColor = .clear
            circle.strokeColor = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 0.9)
            circle.lineWidth = 6 * cachedButtonSizeScale
            circle.glowWidth = 20 * cachedButtonSizeScale
            circle.zPosition = 5
            circle.name = "hitLine"
            addChild(circle)
            hitLineNodes.append(circle)
            // Pulsing animation
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.8),
                SKAction.fadeAlpha(to: 1.0, duration: 0.8)
            ])
            circle.run(SKAction.repeatForever(pulse))
        }
    }

    private func buildHitButtons() {
        guard chart.lanes > 0 else { return }
        hitButtonRects.removeAll()
        for node in hitButtonNodes {
            node.removeFromParent()
        }
        hitButtonNodes.removeAll()

        let buttonHeight = max(70, 90 * cachedButtonSizeScale)
        let layout = laneLayout()
        let isThreeLane = chart.lanes == 3
        let texture = loadTexture(named: "death_metal_texture")
        let neonColors: [SKColor] = [
            SKColor(red: 0.72, green: 0.35, blue: 1.0, alpha: 1.0),
            SKColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0),
            SKColor(red: 0.25, green: 0.9, blue: 1.0, alpha: 1.0)
        ]
        for lane in 0..<chart.lanes {
            let centerX = layout.laneCenters[lane]
            let width = layout.laneWidth * (isThreeLane ? 0.7 : 0.75)
            let rect = CGRect(
                x: centerX - width * 0.5,
                y: hitLineY - buttonHeight * 0.5,
                width: width,
                height: buttonHeight
            )
            hitButtonRects.append(rect)

            let container = SKNode()
            container.position = .zero
            container.name = "hitButton_lane\(lane)"
            container.zPosition = 4
            addChild(container)

            if isThreeLane {
                let laneColor = neonColors[lane % neonColors.count]
                let base = SKShapeNode(rect: rect, cornerRadius: 22)
                base.fillColor = SKColor(white: 0.05, alpha: 0.55)
                base.strokeColor = laneColor
                base.lineWidth = 3.0
                base.glowWidth = 14
                container.addChild(base)

                let inner = SKShapeNode(rect: rect.insetBy(dx: 6, dy: 9), cornerRadius: 18)
                inner.fillColor = SKColor(white: 0.02, alpha: 0.6)
                inner.strokeColor = laneColor.withAlphaComponent(0.45)
                inner.lineWidth = 1.5
                inner.zPosition = 4.2
                container.addChild(inner)

                let highlight = SKShapeNode(rect: rect.insetBy(dx: 10, dy: 14), cornerRadius: 16)
                highlight.strokeColor = SKColor(white: 1.0, alpha: 0.25)
                highlight.lineWidth = 1.0
                highlight.zPosition = 4.3
                container.addChild(highlight)
            } else {
                let base = SKShapeNode(rect: rect, cornerRadius: 18)
                base.fillColor = SKColor(red: 0.12, green: 0.02, blue: 0.03, alpha: 0.95)
                base.strokeColor = SKColor(red: 0.85, green: 0.2, blue: 0.08, alpha: 0.9)
                base.lineWidth = 3.0
                base.glowWidth = 10
                container.addChild(base)

                if let texture {
                    let textureNode = SKSpriteNode(texture: texture)
                    textureNode.position = CGPoint(x: rect.midX, y: rect.midY)
                    textureNode.size = safeSize(rect.size)
                    textureNode.alpha = 0.35
                    textureNode.zPosition = 4.1
                    textureNode.blendMode = .add
                    container.addChild(textureNode)
                }

                let inner = SKShapeNode(rect: rect.insetBy(dx: 8, dy: 10), cornerRadius: 16)
                inner.fillColor = SKColor(red: 0.05, green: 0.01, blue: 0.02, alpha: 0.95)
                inner.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.4)
                inner.lineWidth = 1.5
                inner.zPosition = 4.2
                container.addChild(inner)

                let bevel = SKShapeNode(rect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 16)
                bevel.strokeColor = SKColor(red: 0.95, green: 0.45, blue: 0.1, alpha: 0.5)
                bevel.lineWidth = 1.0
                bevel.zPosition = 4.3
                container.addChild(bevel)
            }

            hitButtonNodes.append(container)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        if isPausedState { return }
        applySettings()
        if chartLoading { return }

        attemptBuildIfPossible()

        // Set start time after first update so size is known
        if songStartTime == nil {
            songStartTime = currentTime + startDelay
        }
        guard songStartTime != nil || songStartWallTime != nil else { return }
        let deltaTime: TimeInterval
        if let lastUpdateTime {
            deltaTime = max(0, currentTime - lastUpdateTime)
        } else {
            deltaTime = 0
        }
        lastUpdateTime = currentTime
        updatePerfLogging(currentTime: currentTime, deltaTime: deltaTime)
        updateTimingDebugOverlay(currentTime: currentTime, deltaTime: deltaTime)
        if let visualsDeferredUntil, !didFinalizeVisuals, currentTime >= visualsDeferredUntil {
            finalizeDeferredVisuals()
        }
        if useNewMechanicsCore, let core = mechanicsCore {
            let rawSongTime = core.rawPlaybackTimeSeconds() ?? 0
            let judgementTime = core.songTimeSeconds()
            latestSongTime = rawSongTime
            latestJudgementTime = judgementTime
            if gamePhase == .countdown, rawSongTime >= 0 { gamePhase = .playing }

            // Update revenge mode
            gameState?.updateRevengeMode(currentTime: judgementTime)
            updateRevengeOverlay(isActive: gameState?.revengeActive == true)

            core.update()
            nextNoteIndex = core.nextSpawnIndex
            updateActiveNotes(songTime: rawSongTime, judgementTime: judgementTime, resolveMisses: false, deltaTime: deltaTime)
        updateHoldNotes(songTime: judgementTime)
        updateTTR4UI()
        if gameState?.isFailed == true { gamePhase = .ended }
        checkSongCompletion()
        return
        }

        // Legacy path: use same authoritative clock (audio + offset) to prevent drift
        let songTime = authoritativeSongTime()
        let judgementTime = songTime
        latestSongTime = songTime
        latestJudgementTime = judgementTime
        if gamePhase == .countdown, songTime >= 0 { gamePhase = .playing }

        // Update revenge mode
        gameState?.updateRevengeMode(currentTime: judgementTime)
        updateRevengeOverlay(isActive: gameState?.revengeActive == true)

        spawnNotesIfNeeded(songTime: songTime)
        updateActiveNotes(songTime: songTime, judgementTime: judgementTime, deltaTime: deltaTime)
        updateHoldNotes(songTime: judgementTime)
        updateTTR4UI()
        if gameState?.isFailed == true { gamePhase = .ended }
        checkSongCompletion()
    }

    private func updatePerfLogging(currentTime: TimeInterval, deltaTime: TimeInterval) {
        guard enablePerfLogging else { return }
        guard !chartLoading, !isPausedState, gameState?.isCompleted != true else { return }
        guard songStartTime != nil || (useNewMechanicsCore && mechanicsCore != nil) else { return }

        if perfLastLogTime == nil {
            perfLastLogTime = currentTime
        }
        perfFrameCount += 1
        if deltaTime > (1.0 / 30.0) {
            perfDtSpikeCount += 1
        }

        guard let lastLog = perfLastLogTime else { return }
        let elapsed = currentTime - lastLog
        if elapsed >= 1.0 {
            let fps = Double(perfFrameCount) / elapsed
            let fpsRounded = (fps * 10).rounded() / 10
            let childCount = children.count
            let activeCount = activeNotes.count
            debugLog("PERF fps=\(fpsRounded) children=\(childCount) activeNotes=\(activeCount) dtSpikes=\(perfDtSpikeCount)")
            perfLastLogTime = currentTime
            perfFrameCount = 0
            perfDtSpikeCount = 0
        }
    }

    private func updateTimingDebugOverlay(currentTime: TimeInterval, deltaTime: TimeInterval) {
        timingDebugFrameCount += 1
        timingDebugFPSElapsed += deltaTime
        if timingDebugFPSElapsed >= 0.25 {
            timingDebugFPS = Double(timingDebugFrameCount) / timingDebugFPSElapsed
            timingDebugFrameCount = 0
            timingDebugFPSElapsed = 0
        }
        timingDebugDtMs = deltaTime * 1000

        guard Self.showTimingDebugOverlay else {
            timingDebugNode?.removeFromParent()
            timingDebugNode = nil
            return
        }

        if timingDebugNode == nil {
            let container = SKNode()
            container.zPosition = 1000
            container.name = "timingDebugOverlay"
            addChild(container)
            timingDebugNode = container
        }
        guard let container = timingDebugNode else { return }

        let songTime = useNewMechanicsCore ? (mechanicsCore?.songTimeSeconds() ?? 0) : authoritativeSongTime()
        let rawAudio = audio.currentTime
        let lines = [
            String(format: "FPS: %.1f", timingDebugFPS),
            String(format: "dt: %.1f ms", timingDebugDtMs),
            String(format: "song: %.2fs", songTime),
            String(format: "audio: %.2fs", rawAudio),
            String(format: "Δ: %.0f ms", (songTime - rawAudio) * 1000)
        ]
        if container.children.count != lines.count {
            container.removeAllChildren()
            for (i, text) in lines.enumerated() {
                let label = SKLabelNode(text: text)
                label.fontName = "Menlo-Regular"
                label.fontSize = 11
                label.fontColor = .white
                label.horizontalAlignmentMode = .left
                label.verticalAlignmentMode = .top
                label.position = CGPoint(x: 12, y: effectiveSize.height - 12 - CGFloat(i) * 14)
                label.zPosition = 1001
                label.name = "timingDebugLine\(i)"
                container.addChild(label)
            }
        }
        for (i, text) in lines.enumerated() {
            guard let label = container.childNode(withName: "timingDebugLine\(i)") as? SKLabelNode else { continue }
            label.text = text
        }
    }

    private func createStarPath(radius: CGFloat, points: Int = 5) -> CGPath {
        let path = CGMutablePath()
        let outerRadius = radius
        let innerRadius = radius * 0.38  // Classic 5-point star ratio
        let angleIncrement = .pi * 2.0 / CGFloat(points)
        let startAngle: CGFloat = -.pi / 2  // Start at top
        
        for i in 0..<points {
            // Draw to outer point
            let outerAngle = startAngle + CGFloat(i) * angleIncrement
            let outerX = outerRadius * cos(outerAngle)
            let outerY = outerRadius * sin(outerAngle)
            
            if i == 0 {
                path.move(to: CGPoint(x: outerX, y: outerY))
            } else {
                path.addLine(to: CGPoint(x: outerX, y: outerY))
            }
            
            // Draw to inner point (between this outer point and next)
            let innerAngle = outerAngle + angleIncrement / 2
            let innerX = innerRadius * cos(innerAngle)
            let innerY = innerRadius * sin(innerAngle)
            path.addLine(to: CGPoint(x: innerX, y: innerY))
        }
        
        path.closeSubpath()
        return path
    }

    private func spawnNotesIfNeeded(songTime: Double) {
        guard nextNoteIndex < notes.count else { return }
        var spawned = 0
        while nextNoteIndex < notes.count && (notes[nextNoteIndex].time - songTime) <= spawnLeadTime {
            if spawned >= 2 { break }
            let note = notes[nextNoteIndex]
            _ = spawnNoteNode(note)
            nextNoteIndex += 1
            spawned += 1
        }
    }

    private func spawnNoteNode(_ note: Note) -> SKNode {
        let layout = laneLayout()
        let laneCenters = layout.laneCenters
        let spawnY = highwayGeometry.topY
        let displayLane = displayLaneIndex(for: note.lane)
        let centerX: CGFloat
        if chart.lanes == 4 {
            centerX = highwayGeometry.laneCenterX(lane: displayLane, y: spawnY, laneCount: chart.lanes)
        } else {
            centerX = laneCenters[displayLane]
        }
        let noteRadius: CGFloat = 30  // Star radius (25% larger)

        let node = dequeuePooledNoteNode(displayLane: displayLane, noteRadius: noteRadius, note: note)
        node.position = CGPoint(x: centerX, y: spawnY)

        // Use lane-specific color for consistency
        let baseColor = laneColors[displayLane % laneColors.count]

        // Add a subtle trailing particle for polish (only for star notes)
        if false && chart.lanes == 4 && cachedNoteGlowEnabled {
            // PERF: Per-note SKEmitterNode creation (disabled).
            // TODO: Per-note trail emitters disabled for performance.
            let trail = particleCache["trail"] ?? createTrailEmitter(color: baseColor)
            particleCache["trail"] = trail
            let emitter = trail.copy() as! SKEmitterNode
            emitter.targetNode = self
            emitter.zPosition = 5
            node.addChild(emitter)
        }

        // For hold notes, create a tail visual
        if note.type == .hold, let duration = note.duration {
            let tailHeight = CGFloat(duration) * noteSpeed
            // PERF: SKShapeNode allocation tied to note tails.
            let tailNode = SKShapeNode(rect: CGRect(x: -noteRadius * 0.6, y: -tailHeight, width: noteRadius * 1.2, height: tailHeight))
            tailNode.fillColor = baseColor.withAlphaComponent(0.3)
            tailNode.strokeColor = baseColor.withAlphaComponent(0.6)
            tailNode.lineWidth = cachedHighContrastNotes ? 2.5 : 1.5
            tailNode.zPosition = 5
            tailNode.name = "holdTail"
            node.addChild(tailNode)
        }

        if node.parent !== notesContainer {
            notesContainer.addChild(node)
        }
        activeNotes[note.id] = node
        return node
    }

    private func createNoteNode(for note: Note, displayLane: Int, noteRadius: CGFloat) -> SKNode {
        var node: SKNode?

        // Use custom images for 3-lane songs, stars for 4-lane songs
        if chart.lanes == 3 {
            // Prefer heavy-metal styled assets if available, with graceful fallback
            let laneImages = ["note_blue", "note_pink", "note_green"]
            let metalLaneImages = ["note_metal_blue", "note_metal_pink", "note_metal_green"]
            let laneIndex = displayLane % laneImages.count
            let candidates = [metalLaneImages[laneIndex], "note_metal", laneImages[laneIndex]]

            for name in candidates {
                if let texture = TextureManager.shared.texture(named: name) {
                    let spriteNode = SKSpriteNode(texture: texture)
                    let isGenericMetal = name == "note_metal"
                    spriteNode.size = CGSize(width: 69, height: 69)  // 25% larger
                    spriteNode.zPosition = 6
                    // If using a generic metal texture, tint per lane for clarity
                    if isGenericMetal {
                        spriteNode.color = laneColors[laneIndex]
                        spriteNode.colorBlendFactor = 0.6
                    }
                    if cachedHighContrastNotes || cachedColorblindPreset != .normal {
                        spriteNode.color = laneColors[laneIndex]
                        spriteNode.colorBlendFactor = cachedHighContrastNotes ? 0.7 : 0.45
                    }
                    node = spriteNode
                    break
                }
            }

            if node == nil {
                // Fallback to star if no images found
                let starPath = createStarPath(radius: noteRadius)
                // PERF: SKShapeNode allocation tied to note visuals.
                let starNode = SKShapeNode(path: starPath)
                let baseColor = laneColors[laneIndex]
                starNode.fillColor = baseColor
                starNode.strokeColor = baseColor.withAlphaComponent(1.0)
                starNode.lineWidth = cachedHighContrastNotes ? 3.5 : 2.0
                starNode.glowWidth = cachedHighContrastNotes ? 20 : 15
                starNode.zPosition = 6
                node = starNode
            }
        } else {
            // Use custom images for 4-lane songs
            let noteImageName: String
            switch displayLane {
            case 0:
                noteImageName = "note_blue_4lane"    // Blue/Cyan lane
            case 1:
                noteImageName = "note_green_4lane"   // Green lane
            case 2:
                noteImageName = "note_orange_4lane"  // Orange/Gold lane
            case 3:
                noteImageName = "note_red_4lane"     // Red/Magenta lane
            default:
                noteImageName = ""
            }

            if !noteImageName.isEmpty,
               let texture = TextureManager.shared.texture(named: noteImageName) {
                let spriteNode = SKSpriteNode(texture: texture)
                spriteNode.size = CGSize(width: 58, height: 58)
                spriteNode.zPosition = 6
                if cachedHighContrastNotes || cachedColorblindPreset != .normal {
                    spriteNode.color = laneColors[displayLane % laneColors.count]
                    spriteNode.colorBlendFactor = cachedHighContrastNotes ? 0.7 : 0.4
                }
                node = spriteNode
            } else {
                // Fallback to star if image not found
                let starPath = createStarPath(radius: noteRadius)
                // PERF: SKShapeNode allocation tied to note visuals.
                let starNode = SKShapeNode(path: starPath)
                let baseColor = laneColors[displayLane % laneColors.count]
                starNode.fillColor = baseColor
                starNode.strokeColor = baseColor.withAlphaComponent(1.0)
                starNode.lineWidth = cachedHighContrastNotes ? 3.5 : 2.0
                starNode.glowWidth = cachedHighContrastNotes ? 20 : 15
                starNode.zPosition = 6

                let shadowStar = SKShapeNode(path: starPath)
                shadowStar.fillColor = SKColor.black.withAlphaComponent(0.4)
                shadowStar.strokeColor = .clear
                shadowStar.position = CGPoint(x: 3, y: -3)
                shadowStar.zPosition = -1
                starNode.addChild(shadowStar)

                node = starNode
            }
        }

        return node ?? SKNode()
    }

    private func updateActiveNotes(songTime: Double, judgementTime: Double, resolveMisses: Bool = true, deltaTime _: TimeInterval) {
        let laneCenters: [CGFloat]
        if chart.lanes == 4 {
            laneCenters = []
        } else {
            laneCenters = laneLayout().laneCenters
        }
        // PERF: Per-frame allocations for bookkeeping arrays.
        var notesToRemove: [String] = []
        
        // To avoid modifying the dictionary while iterating, collect ids to miss in a separate array
        // PERF: Per-frame allocations for miss collection.
        var notesToMiss: [(id: String, node: SKNode, note: Note)] = []
        for (id, node) in activeNotes {
            guard let note = noteLookup[id] else {
                notesToRemove.append(id)
                continue
            }
            // Skip hold notes as they're handled separately
            if note.type == .hold {
                continue
            }
            let judgementDelta = note.time - judgementTime
            let timeForVisuals = chart.lanes == 4 ? judgementTime : songTime
            let delta = note.time - timeForVisuals
            let currentY = hitLineY + CGFloat(delta) * noteSpeed
            let displayLane = displayLaneIndex(for: note.lane)
            var rotationAngle: CGFloat = 0
            if chart.lanes != 3 {
                rotationAngle = 0
            }
            if chart.lanes == 4 {
                let newX = highwayGeometry.laneCenterX(lane: displayLane, y: currentY, laneCount: chart.lanes)
                node.position = CGPoint(x: newX, y: currentY)
                let t = highwayGeometry.normalizedT(forY: currentY)
                let scale = 0.85 + (1.10 - 0.85) * t
                if abs(node.xScale - scale) > 0.01 {
                    node.setScale(scale)
                }
            } else {
                let centerX = laneCenters[displayLane]
                node.position = CGPoint(x: centerX, y: currentY)
            }
            if let spriteNode = node as? SKSpriteNode {
                spriteNode.zRotation = rotationAngle
            }
            // Only miss if still in activeNotes (i.e., not just hit)
            if resolveMisses && judgementDelta < -hitWindow {
                notesToMiss.append((id, node, note))
            }
        }
        // Now process misses after the loop
        for (id, node, note) in notesToMiss {
            // Double-check the note is still in activeNotes (not just hit)
            if activeNotes[id] != nil {
                showMissText(at: node.position)
                register(judgement: .miss, for: note, showMissText: false)
            }
        }
        
        // Clean up orphaned notes
        for id in notesToRemove {
            // PERF: Note node removal/deallocation path.
            if let node = activeNotes.removeValue(forKey: id) {
                recycleNoteNode(node)
            }
        }
    }
    
    private func updateHoldNotes(songTime: Double) {
        // PERF: Per-frame allocations for hold tracking.
        var holdsToRemove: [String] = []
        
        for (id, _) in activeHolds {
            guard let note = noteLookup[id], note.type == .hold, let duration = note.duration else {
                holdsToRemove.append(id)
                continue
            }
            
            let holdEndTime = note.time + duration
            if songTime >= holdEndTime {
                // Check if player held the note successfully
                if touchedLanes.contains(note.lane) {
                    register(judgement: .perfect, for: note)
                } else {
                    register(judgement: .miss, for: note)
                }
                holdsToRemove.append(id)
            }
        }
        
        for id in holdsToRemove {
            activeHolds.removeValue(forKey: id)
        }
    }

    private func judgement(for grade: HitGrade) -> Judgement? {
        switch grade {
        case .perfect:
            return .perfect
        case .great:
            return .great
        case .good:
            return .good
        case .bad:
            // TODO: Add a distinct .bad judgement when scoring supports it.
            return .good
        case .miss:
            return .miss
        case .emptyTap:
            return nil
        }
    }

    private func handleMechanicsHit(noteData: NoteData, grade: HitGrade) {
        guard let note = noteData.sourceNote else { return }
        if note.type == .hold {
            if pendingHoldLane == note.lane {
                pendingHoldStarted = true
            }
            if activeHolds[note.id] == nil {
                activeHolds[note.id] = (pendingHoldTapTime, note.lane)
            }
            return
        }
        guard let judgement = judgement(for: grade) else { return }
        register(judgement: judgement, for: note)
    }

    private func handleMechanicsMiss(noteData: NoteData) {
        guard let note = noteData.sourceNote else { return }
        register(judgement: .miss, for: note)
    }

    private func node(for note: Note) -> SKNode? {
        activeNotes[note.id]
    }

    private func register(judgement: Judgement, for note: Note, showMissText: Bool = false) {
        guard songStartTime != nil else { return }
        gameState?.registerHit(judgement)
        if judgement != .miss {
            audio.playTapSound()
            if SettingsManager.shared.hapticsEnabled {
                hapticGenerator.impactOccurred()
                hapticGenerator.prepare()
            }
        }
        // Always remove from activeNotes immediately on any hit/miss
        // PERF: Note node removal/deallocation path.
        if let node = activeNotes.removeValue(forKey: note.id) {
            node.removeAllActions()
            // Show particle effect based on judgement
            spawnHitParticles(at: node.position, judgement: judgement, lane: note.lane)
            // Single floating judgment text per hit
            showJudgmentText(judgement, at: node.position)
            // TTR4-style lane glow on hit
            flashLaneGlow(lane: note.lane, judgement: judgement)
            // Animated removal with scale burst
            let scale = SKAction.scale(to: 1.8, duration: 0.12)
            let fade = SKAction.fadeOut(withDuration: 0.12)
            let group = SKAction.group([fade, scale])
            node.run(group) { [weak self] in
                self?.recycleNoteNode(node)
            }
        }
    }
    
    private func spawnHitParticles(at position: CGPoint, judgement: Judgement, lane: Int) {
        let reduceFlashing = SettingsManager.shared.reduceFlashing
        let isExtreme = gameState?.difficulty == .extreme
        guard enableGameplayEmitters else { return }
        // PERF: SKEmitterNode allocation tied to note hits.
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = TextureManager.shared.texture(named: "spark") ?? createSparkTexture()
        
        // Color based on judgement
        let color: SKColor
        let numParticles: Int
        let scale: CGFloat
        switch judgement {
        case .perfect:
            color = SKColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1.0)
            numParticles = reduceFlashing ? 18 : (isExtreme ? 24 : 40)
            scale = reduceFlashing ? 0.35 : (isExtreme ? 0.42 : 0.5)  // Brighter burst for perfect
        case .great:
            color = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1.0)
            numParticles = reduceFlashing ? 14 : (isExtreme ? 16 : 25)
            scale = reduceFlashing ? 0.3 : (isExtreme ? 0.33 : 0.4)
        case .good:
            color = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
            numParticles = reduceFlashing ? 10 : (isExtreme ? 12 : 18)
            scale = reduceFlashing ? 0.25 : (isExtreme ? 0.28 : 0.3)
        case .miss:
            color = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
            numParticles = reduceFlashing ? 6 : (isExtreme ? 6 : 12)
            scale = reduceFlashing ? 0.15 : (isExtreme ? 0.18 : 0.2)
        }
        
        emitter.particleColor = color
        emitter.particleBirthRate = 0
        emitter.numParticlesToEmit = numParticles
        emitter.particleLifetime = 0.7
        emitter.particleLifetimeRange = 0.3
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 180
        emitter.particleSpeedRange = 120
        emitter.particleScale = scale
        emitter.particleScaleRange = 0.25
        emitter.particleScaleSpeed = -0.5
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.3
        emitter.particleBlendMode = .add
        
        addChild(emitter)
        
        // Burst emission then remove
        emitter.run(SKAction.sequence([
            SKAction.run { emitter.particleBirthRate = 1200 },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { emitter.particleBirthRate = 0 },
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ]))
    }

    private func spawnHitMarker(_ judgement: Judgement, at position: CGPoint) {
        let text: String
        let color: SKColor
        switch judgement {
        case .perfect:
            text = "PERFECT"
            color = SKColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1.0)
        case .great:
            text = "GREAT"
            color = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1.0)
        case .good:
            text = "GOOD"
            color = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        case .miss:
            text = "MISS"
            color = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        }
        
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 26
        label.fontColor = color
        label.position = position
        label.zPosition = 150
        label.setScale(0.6)
        addChild(label)
        
        let rise = SKAction.moveBy(x: 0, y: 50, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([rise, fade])
        label.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }

    private func createTrailEmitter(color: SKColor) -> SKEmitterNode {
        // PERF: SKEmitterNode allocation tied to note trails.
        let emitter = SKEmitterNode()
        emitter.particleTexture = TextureManager.shared.texture(named: "spark") ?? createSparkTexture()
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBirthRate = 80
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 0.35
        emitter.particleLifetimeRange = 0.1
        emitter.particleSpeed = -40
        emitter.particleSpeedRange = 20
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 4
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.25
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -0.4
        emitter.particleBlendMode = .add
        emitter.zPosition = 5
        return emitter
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPausedState else { return }
        for touch in touches {
            let location = touch.location(in: self)
            // Triple-tap top-left corner toggles timing debug overlay
            let inDebugZone = location.x < effectiveSize.width * 0.2 && location.y > effectiveSize.height * 0.75
            if inDebugZone {
                let t = touch.timestamp
                if t - timingDebugLastTapTime > 0.5 { timingDebugTapCount = 0 }
                timingDebugTapCount += 1
                timingDebugLastTapTime = t
                if timingDebugTapCount >= 3 {
                    timingDebugTapCount = 0
                    Self.showTimingDebugOverlay.toggle()
                }
                continue
            }
            guard let displayLane = hitLaneIndex(for: location) else { continue }
            let logicalLane = logicalLaneIndex(for: displayLane)
            if useNewMechanicsCore, let core = mechanicsCore {
                pendingHoldLane = logicalLane
                pendingHoldTapTime = core.songTimeSeconds()
                pendingHoldStarted = false
                _ = core.handleTap(laneIndex: logicalLane)
                if pendingHoldStarted {
                    touchedLanes.insert(logicalLane)
                    touchLaneMap[ObjectIdentifier(touch)] = logicalLane
                }
                pendingHoldLane = nil
                continue
            }
            let result = judgeTap(lane: logicalLane, tapTime: authoritativeSongTime())
            if result.startedHold {
                touchedLanes.insert(logicalLane)
                touchLaneMap[ObjectIdentifier(touch)] = logicalLane
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPausedState else { return }
        // Hold tracking is based on touch begin/end; move does not re-judge taps.
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPausedState else { return }
        for touch in touches {
            let key = ObjectIdentifier(touch)
            if let lane = touchLaneMap[key] {
                touchedLanes.remove(lane)
                touchLaneMap.removeValue(forKey: key)
            }
        }
    }
    
    private func getJudgement(for delta: Double) -> Judgement {
        if delta <= perfectWindow {
            return .perfect
        } else if delta <= greatWindow {
            return .great
        } else {
            return .good
        }
    }

    private struct TapResult {
        let startedHold: Bool
    }

    private func judgeTap(lane: Int, tapTime: TimeInterval) -> TapResult {
        guard songStartTime != nil || songStartWallTime != nil else { return TapResult(startedHold: false) }
        guard lane >= 0 && lane < chart.lanes else { return TapResult(startedHold: false) }

        let candidates = notes.filter {
            $0.lane == lane &&
            activeNotes[$0.id] != nil &&
            abs($0.time - tapTime) <= hitWindow
        }

        guard let target = candidates.min(by: { abs($0.time - tapTime) < abs($1.time - tapTime) }) else {
            applyGhostTapMiss(lane: lane)
            return TapResult(startedHold: false)
        }

        if target.type == .hold {
            if activeHolds[target.id] == nil {
                activeHolds[target.id] = (tapTime, lane)
            }
            return TapResult(startedHold: true)
        }

        let delta = abs(target.time - tapTime)
        let judgement = getJudgement(for: delta)
        register(judgement: judgement, for: target)
        return TapResult(startedHold: false)
    }

    private func applyGhostTapMiss(lane: Int) {
        gameState?.registerHit(.miss)
        let displayLane = displayLaneIndex(for: lane)
        let layout = laneLayout()
        let centerX = layout.laneCenters[displayLane]
        showMissText(at: CGPoint(x: centerX, y: hitLineY))
        flashLaneGlow(lane: lane, judgement: .miss)
    }
    
    private func showMissText(at position: CGPoint) {
        let label = SKLabelNode(text: "MISS")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 18
        label.fontColor = .red
        label.position = position
        label.zPosition = 100
        addChild(label)
        
        let fade = SKAction.sequence([
            SKAction.wait(forDuration: 0.75),
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ])
        label.run(fade)
    }
    
    private func showJudgmentText(_ judgement: Judgement, at position: CGPoint) {
        let text: String
        let color: SKColor
        let fontSize: CGFloat
        
        switch judgement {
        case .perfect:
            text = "PERFECT"
            color = SKColor(red: 1.0, green: 0.95, blue: 0.2, alpha: 0.7)
            fontSize = 14
        case .great:
            text = "GREAT"
            color = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.6)
            fontSize = 12
        case .good:
            text = "GOOD"
            color = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.5)
            fontSize = 11
        case .miss:
            text = "MISS"
            color = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.5)
            fontSize = 11
        }
        
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = fontSize
        label.fontColor = color
        label.position = CGPoint(x: position.x, y: position.y + 30)
        label.zPosition = 100
        label.alpha = 0.8
        label.setScale(0.6)
        addChild(label)
        
        // Smaller, more subtle pop-up animation
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.08)
        let moveUp = SKAction.moveBy(x: 0, y: 20, duration: 0.35)
        let fade = SKAction.fadeOut(withDuration: 0.15)
        
        let sequence = SKAction.sequence([
            scaleUp,
            SKAction.group([moveUp, SKAction.wait(forDuration: 0.15)]),
            fade,
            SKAction.removeFromParent()
        ])
        label.run(sequence)
    }
    
    private func flashLaneGlow(lane: Int, judgement: Judgement) {
        guard cachedNoteGlowEnabled else { return }
        let displayLane = displayLaneIndex(for: lane)
        guard displayLane >= 0 && displayLane < laneGlowNodes.count else { return }
        let glowNode = laneGlowNodes[displayLane]
        
        let intensity: CGFloat
        switch judgement {
        case .perfect: intensity = 0.25
        case .great: intensity = 0.18
        case .good: intensity = 0.12
        case .miss: intensity = 0.08
        }

        glowNode.alpha = cachedReduceFlashing ? intensity * 0.6 : intensity
        let fade = SKAction.fadeOut(withDuration: 0.4)
        glowNode.run(fade)
    }

    private func updateRevengeOverlay(isActive: Bool) {
        if isActive {
            // Start revenge background animation if not already running
            if !isRevengeAnimating {
                startRevengeBackgroundAnimation()
            }
        } else {
            // Stop revenge animation and restore normal background
            stopRevengeBackgroundAnimation()
        }
    }
    
    private func startRevengeBackgroundAnimation() {
        let shouldDisable = SettingsManager.shared.disableBackgroundAnimations || SettingsManager.shared.backgroundIntensity == .static
        // Load and prepare all revenge background images
        if revengeBackgroundNodes.isEmpty {
            for imageName in revengeBackgroundImages {
                var bgImage: UIImage?
                
                if let image = UIImage(named: imageName) {
                    bgImage = image
                } else if let path = Bundle.main.path(forResource: imageName.replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: ".png", with: ""), ofType: imageName.contains(".jpg") ? "jpg" : "png"),
                          let image = UIImage(contentsOfFile: path) {
                    bgImage = image
                }
                
                guard let bgImage = bgImage else {
                    debugLog("Warning: Could not load revenge background: \(imageName)")
                    continue
                }
                
                let s = effectiveSize
                let bgSprite = SKSpriteNode(texture: SKTexture(image: bgImage))
                bgSprite.position = CGPoint(x: s.width * 0.5, y: s.height * 0.5)
                bgSprite.size = safeSize(s)
                bgSprite.zPosition = -9
                bgSprite.alpha = 0.0
                addChild(bgSprite)
                revengeBackgroundNodes.append(bgSprite)
            }
        }
        
        // Hide normal background
        laneBackgroundNode?.alpha = 0.0
        
        // Start animation
        if !revengeBackgroundNodes.isEmpty {
            isRevengeAnimating = true
            revengeAnimationIndex = 0
            revengeBackgroundNodes[0].alpha = 1.0
            if shouldDisable {
                isRevengeAnimating = false
            } else {
                animateRevengeBackground()
            }
        }
    }
    
    private func animateRevengeBackground() {
        guard isRevengeAnimating else { return }
        if SettingsManager.shared.disableBackgroundAnimations || SettingsManager.shared.backgroundIntensity == .static {
            isRevengeAnimating = false
            return
        }
        
        let delay: TimeInterval = 0.3  // Fast animation for intense effect
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isRevengeAnimating else { return }
            
            let currentNode = self.revengeBackgroundNodes[self.revengeAnimationIndex]
            let nextIndex = (self.revengeAnimationIndex + 1) % self.revengeBackgroundNodes.count
            let nextNode = self.revengeBackgroundNodes[nextIndex]
            
            // Quick fade between images
            let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.2)
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
            
            currentNode.run(fadeOut)
            nextNode.run(fadeIn)
            
            self.revengeAnimationIndex = nextIndex
            self.animateRevengeBackground()
        }
    }
    
    private func stopRevengeBackgroundAnimation() {
        isRevengeAnimating = false
        
        // Fade out all revenge backgrounds
        for node in revengeBackgroundNodes {
            node.run(SKAction.fadeOut(withDuration: 0.3))
        }
        
        // Restore normal background
        laneBackgroundNode?.run(SKAction.fadeIn(withDuration: 0.3))
    }
    
    private func shakeScreen() {
        guard cachedScreenShakeEnabled else { return }
        let shakeAmount: CGFloat = 4
        let shakeDuration: TimeInterval = 0.03

        let moveRight = SKAction.moveBy(x: shakeAmount, y: 0, duration: shakeDuration)
        let moveLeft = SKAction.moveBy(x: -shakeAmount * 2, y: 0, duration: shakeDuration)
        let moveCenter = SKAction.moveBy(x: shakeAmount, y: 0, duration: shakeDuration)

        let shakeSequence = SKAction.sequence([moveRight, moveLeft, moveCenter])
        let repeatShake = SKAction.repeat(shakeSequence, count: 2)

        for child in children {
            if child.zPosition < 100 {  // Don't shake UI elements
                child.run(repeatShake)
            }
        }
    }
    
    private func updateTTR4UI() {
        guard let gameState = gameState else { return }
        
        // Update combo with TTR4-style animation
        if gameState.combo != lastCombo {
            animateComboChange(from: lastCombo, to: gameState.combo)
            lastCombo = gameState.combo
        }
        
        // Update multiplier with TTR4-style animation
        if gameState.multiplier != lastMultiplier {
            animateMultiplierChange(from: lastMultiplier, to: gameState.multiplier)
            lastMultiplier = gameState.multiplier
        }
    }
    
    private func animateComboChange(from oldCombo: Int, to newCombo: Int) {
        // Create temporary combo display for milestone celebrations
        let difficulty = gameState?.difficulty ?? .medium
        let milestones = comboMilestones(for: difficulty)
        let repeatMilestone = comboRepeatMilestone(for: difficulty)
        let isBaseMilestone = milestones.contains(newCombo)
        let isRepeatMilestone = newCombo >= repeatMilestone && newCombo % repeatMilestone == 0
        if newCombo > 0 && (isBaseMilestone || isRepeatMilestone) {
            let milestone = SKLabelNode(text: "\(newCombo) COMBO!")
            milestone.fontName = "AvenirNext-Heavy"
            milestone.fontSize = 48
            milestone.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
            milestone.position = CGPoint(x: effectiveSize.width * 0.5, y: effectiveSize.height * 0.6)
            milestone.zPosition = 200
            milestone.setScale(0.5)
            addChild(milestone)
            
            // TTR4-style burst animation
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
            let wait = SKAction.wait(forDuration: 0.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            
            let sequence = SKAction.sequence([scaleUp, scaleDown, wait, fadeOut, SKAction.removeFromParent()])
            milestone.run(sequence)
            
            // Screen flash + shake effect
            flashScreen(color: SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.2))
            shakeScreen()

            // Subtle coin popup (visual only; coins rewarded at song end)
            let text = coinPopupText(forCombo: newCombo, difficulty: difficulty)
            spawnCoinPopup(at: CGPoint(x: effectiveSize.width * 0.5, y: effectiveSize.height * 0.55), text: text)
        }
    }
    
    private func animateMultiplierChange(from oldMultiplier: Int, to newMultiplier: Int) {
        if newMultiplier > oldMultiplier {
            // Multiplier increased - celebrate!
            let multiplierText = SKLabelNode(text: "\(newMultiplier)X MULTIPLIER!")
            multiplierText.fontName = "AvenirNext-Heavy"
            multiplierText.fontSize = 36
            multiplierText.fontColor = SKColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 1.0)
            multiplierText.position = CGPoint(x: effectiveSize.width * 0.5, y: effectiveSize.height * 0.7)
            multiplierText.zPosition = 200
            multiplierText.setScale(0.5)
            addChild(multiplierText)
            
            // Lightning effect
            spawnMultiplierBurst(at: multiplierText.position)
            
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.15)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            let wait = SKAction.wait(forDuration: 0.4)
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            
            let sequence = SKAction.sequence([scaleUp, scaleDown, wait, fadeOut, SKAction.removeFromParent()])
            multiplierText.run(sequence)

            // Subtle coin popup for milestone multipliers only
            let difficulty = gameState?.difficulty ?? .medium
            let milestones = multiplierMilestones(for: difficulty)
            if milestones.contains(newMultiplier) {
                let text = coinPopupText(forMultiplier: newMultiplier, difficulty: difficulty)
                spawnCoinPopup(at: CGPoint(x: effectiveSize.width * 0.5, y: effectiveSize.height * 0.65), text: text)
            }
        }
    }

    private func coinPopupText(forCombo combo: Int, difficulty: Difficulty) -> String {
        // Tiered visual amounts; actual coins awarded at end
        let milestones = comboMilestones(for: difficulty)
        if let idx = milestones.firstIndex(of: combo) {
            switch idx {
            case 0: return "+1 Tap Coins"
            case 1: return "+2 Tap Coins"
            case 2: return "+3 Tap Coins"
            default: return "+5 Tap Coins"
            }
        }
        let repeatMilestone = comboRepeatMilestone(for: difficulty)
        if combo >= repeatMilestone && combo % repeatMilestone == 0 {
            return "+5 Tap Coins"
        }
        return "+1 Tap Coins"
    }

    private func coinPopupText(forMultiplier mult: Int, difficulty: Difficulty) -> String {
        let milestones = multiplierMilestones(for: difficulty)
        if let idx = milestones.firstIndex(of: mult) {
            switch idx {
            case 0: return "+1 Tap Coins"
            case 1: return "+2 Tap Coins"
            default: return "+3 Tap Coins"
            }
        }
        return "+1 Tap Coins"
    }

    private func spawnCoinPopup(at position: CGPoint, text: String) {
        // Yellow coin circle
        let coin = SKShapeNode(circleOfRadius: 14)
        coin.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1.0)
        coin.strokeColor = SKColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)
        coin.lineWidth = 3
        coin.position = position
        coin.zPosition = 201
        addChild(coin)

        // Rising text
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 20
        label.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1.0)
        label.position = CGPoint(x: position.x + 28, y: position.y - 4)
        label.zPosition = 201
        addChild(label)

        // Animation
        let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([rise, fade])

        coin.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        label.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }
    
    private func spawnMultiplierBurst(at position: CGPoint) {
        for _ in 0..<8 {
            let star = SKShapeNode(circleOfRadius: 4)
            star.fillColor = SKColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 1.0)
            star.strokeColor = .white
            star.lineWidth = 1
            star.position = position
            star.zPosition = 199
            addChild(star)
            
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...100)
            let destination = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            let move = SKAction.move(to: destination, duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let group = SKAction.group([move, fade])
            star.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }
    
    private func flashScreen(color: SKColor) {
        guard !cachedReduceFlashing else { return }
        let s = effectiveSize
        let flash = SKShapeNode(rect: CGRect(x: 0, y: 0, width: s.width, height: s.height))
        flash.fillColor = color
        flash.strokeColor = .clear
        flash.zPosition = 150
        flash.alpha = 1.0
        addChild(flash)
        
        let fade = SKAction.fadeOut(withDuration: 0.3)
        flash.run(SKAction.sequence([fade, SKAction.removeFromParent()]))
    }
    
    func checkSongCompletion() {
        guard gamePhase == .playing else { return }
        guard gameState?.isCompleted == false else { return }
        guard songStartTime != nil else { return }
        guard gameState?.totalNotes ?? 0 > 0 else { return }  // Don't complete on empty chart / before load

        let noMoreQueuedNotes: Bool
        if useNewMechanicsCore, let core = mechanicsCore {
            noMoreQueuedNotes = core.nextSpawnIndex >= core.chartNotes.count
        } else {
            noMoreQueuedNotes = nextNoteIndex >= notes.count
        }
        let noActiveNotes = activeNotes.isEmpty
        let noActiveHolds = activeHolds.isEmpty
        // Account for offset when checking if we're past the last note
        let adjustedLastNoteEndTime = lastNoteEndTime + chart.offset
        let timePastLastNote = latestSongTime >= adjustedLastNoteEndTime + 1.0

        if (noMoreQueuedNotes && noActiveNotes && noActiveHolds) || (timePastLastNote && noActiveNotes && noActiveHolds) {
            gamePhase = .ended
            DispatchQueue.main.async { [weak self] in
                self?.gameState?.markCompleted()
                self?.audio.stop()
            }
        }
    }

    private var latestSongTime: Double = 0
}
