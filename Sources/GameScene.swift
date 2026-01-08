import SpriteKit
import SwiftUI
import CoreMotion

final class GameScene: SKScene {
    weak var gameState: GameState?

    private var chart: Chart = ChartLoader.loadChart(for: SongMetadata.default, difficulty: .medium).chart
    private var notes: [Note] = []
    private var noteLookup: [UUID: Note] = [:]
    private var nextNoteIndex: Int = 0
    private var activeNotes: [UUID: SKNode] = [:]
    private var audio = GameAudioEngine(song: SongMetadata.default)
    private var didBuildLanes: Bool = false
    private var particleCache: [String: SKEmitterNode] = [:]
    private var isPausedState: Bool = false
    private var song: SongMetadata = .default
    
    // Shake detection
    private let motionManager = CMMotionManager()
    private var lastShakeTime: TimeInterval = 0
    private let shakeDebounce: TimeInterval = 0.5
    private var shakeThreshold: Double = 1.8
    
    // Hold note tracking
    private var activeHolds: [UUID: (startTime: TimeInterval, lane: Int)] = [:]
    private var touchedLanes: Set<Int> = []

    private var songStartTime: TimeInterval?
    private let startDelay: TimeInterval = 0.35
    private let spawnLeadTime: Double = 2.8   // Increased for better visual feedback
    private let hitWindow: Double = 0.16  // Optimized timing window - Perfect: ±50ms, Great: ±80ms, Good: ±160ms
    private let noteSpeed: CGFloat = 450   // Optimized for smooth gameplay at 60fps
    private let hitLineOffset: CGFloat = 200  // Distance from bottom of screen (moved up slightly)
    private var hitLineY: CGFloat = 200  // Calculated dynamically based on screen size
    private var lastNoteEndTime: Double = 0
    private let laneAngleFactor: CGFloat = 0.15  // Controls the horizontal angle of lanes as notes fall (adjust for lane angle)

    private let laneColors: [SKColor] = [
        SKColor(red: 0.4, green: 0.65, blue: 0.75, alpha: 1),    // Desaturated Cyan (lane 0)
        SKColor(red: 0.45, green: 0.75, blue: 0.55, alpha: 1),   // Desaturated Green (lane 1)
        SKColor(red: 0.85, green: 0.7, blue: 0.4, alpha: 1),     // Desaturated Gold (lane 2)
        SKColor(red: 0.85, green: 0.5, blue: 0.65, alpha: 1)     // Desaturated Magenta (lane 3)
    ]

    private var revengeOverlayNode: SKSpriteNode?
    private var laneBackgroundNode: SKSpriteNode?
    
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
    private var laneGlowNodes: [SKShapeNode] = []
    private var lastCombo: Int = 0
    private var lastMultiplier: Int = 1

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
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 120
        view.shouldCullNonVisibleNodes = true
    }

    func setSong(_ song: SongMetadata) {
        self.song = song
        // Fully reset audio to avoid bleed-through between tracks
        audio.stop()
        audio = GameAudioEngine(song: song)
    }

    func start() {
        removeAllChildren()
        audio.stop()
        
        // Reset revenge animation
        revengeBackgroundNodes.removeAll()
        isRevengeAnimating = false
        revengeAnimationIndex = 0
        
        // Reset game state FIRST before loading chart
        gameState?.reset()
        
        let requestedDifficulty = gameState?.difficulty ?? .medium
        let loadResult = ChartLoader.loadChart(for: song, difficulty: requestedDifficulty)
        chart = loadResult.chart
        if loadResult.wasFallback {
            gameState?.difficulty = loadResult.usedDifficulty
            print("⚠️ Requested difficulty \(requestedDifficulty.rawValue) missing, using \(loadResult.usedDifficulty.rawValue) from \(loadResult.fileName)")
        }
        notes = chart.notes.sorted { $0.time < $1.time }
        noteLookup = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        lastNoteEndTime = notes.map { $0.time + ($0.duration ?? 0) }.max() ?? 0
        nextNoteIndex = 0
        activeNotes.removeAll()
        activeHolds.removeAll()
        songStartTime = nil
        latestSongTime = 0
        didBuildLanes = false
        isPausedState = false
        gameState?.totalNotes = notes.count
        lastCombo = 0
        lastMultiplier = 1
        
        print("Game started - Loaded \(notes.count) notes from chart")
        print("Chart: \(chart.songName), BPM: \(chart.bpm), Lanes: \(chart.lanes)")
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
        let songTime = latestSongTime
        
        // Find all active shake notes near current time
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

    // Manual revenge activation (button)
    func activateRevengeFromButton() {
        guard let gameState else { return }
        guard gameState.canActivateRevenge() else { return }
        gameState.activateRevengeMode(currentTime: latestSongTime)
    }
    
    func startMusic() {
        // Start music and align song timeline to the same delay
        if audio.isReady {
            audio.play(after: startDelay)
            songStartTime = nil  // Reset so update can align to the shared startDelay
        } else {
            print("Audio not ready; skipping play")
        }
    }
    
    func pause() {
        isPausedState = true
        isPaused = true
        audio.pause()
    }
    
    func resume() {
        isPausedState = false
        isPaused = false
        audio.resume()
    }
    
    func stop() {
        audio.stop()
        removeAllChildren()
        motionManager.stopAccelerometerUpdates()
    }

    private func buildLanes() {
        // Calculate hit line position from bottom of screen based on lane count
        hitLineY = chart.lanes == 4 ? 250 : hitLineOffset
        
        // Add animated neon background
        addAnimatedBackground()

        // addSpotlights()  // Removed: transparent triangles
        addStarBursts()
        addStageBase()
        
        // Add visual lane separators
        buildLaneGuides()
        
        // Build TTR4-style lane glow effects
        buildLaneGlows()
        
        // Removed translucent lane overlays - using background images instead
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

    private func addAnimatedBackground() {
        // Add neon lane background with gameplay image based on lane count
        let backgroundName = chart.lanes == 4 ? "gameplay_background_4lane" : "gameplay_background"
        let backgroundOffset: CGFloat = chart.lanes == 4 ? 80 : 120  // 4-lane background moved down (lower offset)
        
        if let bgImage = UIImage(named: backgroundName) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: backgroundName, ofType: "png") ?? "") {
            let bgSprite = SKSpriteNode(texture: SKTexture(image: bgImage))
            // Shift background up so buttons align with hit line
            bgSprite.position = CGPoint(x: size.width / 2, y: size.height / 2 + backgroundOffset)
            bgSprite.size = size
            bgSprite.zPosition = -10
            addChild(bgSprite)
            laneBackgroundNode = bgSprite
            print("Loaded \(backgroundName) for \(chart.lanes) lanes")
        } else {
            print("Warning: Could not load \(backgroundName).png")
        }
    }

    private func addSpotlights() {
        let spotlightColors: [SKColor] = [
            SKColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 0.35),
            SKColor(red: 0.35, green: 0.80, blue: 1.0, alpha: 0.30),
            SKColor(red: 1.00, green: 0.65, blue: 0.35, alpha: 0.32)
        ]

        let centerY = size.height * 0.65
        let height: CGFloat = size.height * 0.9
        let width: CGFloat = size.width * 0.22
        let xPositions: [CGFloat] = [size.width * 0.2, size.width * 0.5, size.width * 0.8]

        for (index, x) in xPositions.enumerated() {
            let color = spotlightColors[index % spotlightColors.count]
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: size.height))
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
        let emitter = SKEmitterNode()
        emitter.particleTexture = createSparkTexture()
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
        emitter.position = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
        emitter.particlePositionRange = CGVector(dx: size.width * 0.7, dy: size.height * 0.4)
        emitter.zPosition = 2
        emitter.particleBlendMode = SKBlendMode.add
        addChild(emitter)
    }

    private func addStageBase() {
        let stageHeight: CGFloat = 90
        let stage = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: stageHeight))
        stage.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        stage.strokeColor = SKColor.white.withAlphaComponent(0.08)
        stage.lineWidth = 2
        stage.zPosition = 3
        addChild(stage)

        // Simple crowd silhouette using repeating arcs
        let crowd = SKShapeNode()
        let path = CGMutablePath()
        let bumps = Int(size.width / 20)
        for i in 0...bumps {
            let x = CGFloat(i) * 20
            let y: CGFloat = stageHeight * 0.4 + CGFloat.random(in: -6...6)
            path.addArc(center: CGPoint(x: x, y: y), radius: 12, startAngle: 0, endAngle: .pi, clockwise: false)
        }
        crowd.path = path
        crowd.fillColor = SKColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.65)
        crowd.strokeColor = .clear
        crowd.zPosition = 3.5
        addChild(crowd)
    }

    private func buildLaneGuides() {
        let laneWidth = chart.lanes == 3 ? (size.width * 0.7) / CGFloat(chart.lanes) : size.width / CGFloat(chart.lanes)
        let laneStartX = chart.lanes == 3 ? (size.width - size.width * 0.7) / 2 : 0
        
        for lane in 0..<chart.lanes {
            // Lane separators (vertical lines between lanes)
            if lane < chart.lanes - 1 {
                let x = laneStartX + CGFloat(lane + 1) * laneWidth
                let line = SKShapeNode(rect: CGRect(x: x - 1, y: 0, width: 2, height: size.height))
                line.fillColor = SKColor(red: 0.5, green: 0.5, blue: 0.7, alpha: 0.15)
                line.strokeColor = .clear
                line.zPosition = 1
                addChild(line)
            }
        }
        
        // Add subtle vignette on top
        let vignette = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        vignette.fillColor = SKColor.black.withAlphaComponent(0.22)
        vignette.strokeColor = .clear
        vignette.zPosition = 4
        addChild(vignette)
    }
    
    private func buildLaneGlows() {
        laneGlowNodes.removeAll()
        let laneWidth = chart.lanes == 3 ? (size.width * 0.7) / CGFloat(chart.lanes) : size.width / CGFloat(chart.lanes)
        let laneStartX = chart.lanes == 3 ? (size.width - size.width * 0.7) / 2 : 0
        
        for lane in 0..<chart.lanes {
            let centerX = laneStartX + CGFloat(lane) * laneWidth + laneWidth * 0.5
            let glowRect = CGRect(x: centerX - laneWidth * 0.5, y: 0, width: laneWidth, height: size.height)
            let glow = SKShapeNode(rect: glowRect)
            glow.fillColor = laneColors[lane % laneColors.count]
            glow.strokeColor = .clear
            glow.alpha = 0.0
            glow.zPosition = 2
            glow.blendMode = .add
            addChild(glow)
            laneGlowNodes.append(glow)
        }
    }
    
    private func buildHitLine() {
        // Create 3 glowing circles for hit targets
        guard chart.lanes > 0 else { return }
        let laneWidth = size.width / CGFloat(chart.lanes)
        
        for lane in 0..<chart.lanes {
            let centerX = CGFloat(lane) * laneWidth + laneWidth * 0.5
            let circle = SKShapeNode(circleOfRadius: 35)
            circle.position = CGPoint(x: centerX, y: hitLineY)
            circle.fillColor = .clear
            circle.strokeColor = SKColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 0.9)
            circle.lineWidth = 6
            circle.glowWidth = 20
            circle.zPosition = 5
            addChild(circle)
            
            // Pulsing animation
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.8),
                SKAction.fadeAlpha(to: 1.0, duration: 0.8)
            ])
            circle.run(SKAction.repeatForever(pulse))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        if isPausedState { return }

        if !didBuildLanes && size.width > 0 {
            buildLanes()
            // buildHitLine() - Hidden to show background buttons
            didBuildLanes = true
        }

        // Set start time after first update so size is known
        if songStartTime == nil {
            songStartTime = currentTime + startDelay
        }
        guard let songStartTime else { return }
        let songTime = max(0, currentTime - songStartTime)
        latestSongTime = songTime
        
        // Update revenge mode
        gameState?.updateRevengeMode(currentTime: songTime)
        updateRevengeOverlay(isActive: gameState?.revengeActive == true)
        
        spawnNotesIfNeeded(songTime: songTime)
        updateActiveNotes(songTime: songTime)
        updateHoldNotes(songTime: songTime)
        updateTTR4UI()
        checkSongCompletion()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        didBuildLanes = false
        // Keep overlay in sync with size changes
        if let overlay = revengeOverlayNode {
            overlay.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            overlay.size = size
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
        let laneWidth = chart.lanes == 3 ? (size.width * 0.7) / CGFloat(chart.lanes) : size.width / CGFloat(chart.lanes)
        let laneStartX = chart.lanes == 3 ? (size.width - size.width * 0.7) / 2 : 0
        while nextNoteIndex < notes.count && (notes[nextNoteIndex].time - songTime) <= spawnLeadTime {
            let note = notes[nextNoteIndex]
            let centerX = laneStartX + CGFloat(note.lane) * laneWidth + laneWidth * 0.5
            let noteRadius: CGFloat = 30  // Star radius (25% larger)
            
            let node: SKNode
            
            // Use custom images for 3-lane songs, stars for 4-lane songs
            if chart.lanes == 3 {
                let noteImages = ["note_blue", "note_pink", "note_green"]
                let imageName = noteImages[note.lane % noteImages.count]
                
                if let noteImage = UIImage(named: imageName) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: imageName, ofType: "png") ?? "") {
                    let spriteNode = SKSpriteNode(texture: SKTexture(image: noteImage))
                    spriteNode.size = CGSize(width: 69, height: 69)  // 25% larger
                    spriteNode.zPosition = 6
                    node = spriteNode
                } else {
                    // Fallback to star if image not found
                    let starPath = createStarPath(radius: noteRadius)
                    let starNode = SKShapeNode(path: starPath)
                    starNode.fillColor = laneColors[note.lane % laneColors.count]
                    starNode.strokeColor = laneColors[note.lane % laneColors.count].withAlphaComponent(1.0)
                    starNode.lineWidth = 2.0
                    starNode.glowWidth = 15
                    starNode.zPosition = 6
                    node = starNode
                }
            } else {
                // Use stars for 4-lane songs
                let starPath = createStarPath(radius: noteRadius)
                let starNode = SKShapeNode(path: starPath)
                let baseColor = laneColors[note.lane % laneColors.count]
                starNode.fillColor = baseColor
                starNode.strokeColor = baseColor.withAlphaComponent(1.0)
                starNode.lineWidth = 2.0
                starNode.glowWidth = 15
                starNode.zPosition = 6
                
                // Add 3D depth with darker shadow
                let shadowStar = SKShapeNode(path: starPath)
                shadowStar.fillColor = SKColor.black.withAlphaComponent(0.4)
                shadowStar.strokeColor = .clear
                shadowStar.position = CGPoint(x: 3, y: -3)
                shadowStar.zPosition = -1
                starNode.addChild(shadowStar)
                
                node = starNode
            }
            
            node.position = CGPoint(x: centerX, y: size.height + 40)
            
            // Use lane-specific color for consistency
            let baseColor = laneColors[note.lane % laneColors.count]
            
            // Add a subtle trailing particle for polish (only for star notes)
            if chart.lanes == 4 {
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
                let tailNode = SKShapeNode(rect: CGRect(x: -noteRadius * 0.6, y: -tailHeight, width: noteRadius * 1.2, height: tailHeight))
                tailNode.fillColor = baseColor.withAlphaComponent(0.3)
                tailNode.strokeColor = baseColor.withAlphaComponent(0.6)
                tailNode.lineWidth = 1.5
                tailNode.zPosition = 5
                node.addChild(tailNode)
            }
            
            addChild(node)
            activeNotes[note.id] = node
            nextNoteIndex += 1
        }
    }

    private func updateActiveNotes(songTime: Double) {
        let laneWidth = chart.lanes == 3 ? (size.width * 0.7) / CGFloat(chart.lanes) : size.width / CGFloat(chart.lanes)
        let laneStartX = chart.lanes == 3 ? (size.width - size.width * 0.7) / 2 : 0
        var notesToRemove: [UUID] = []
        
        for (id, node) in activeNotes {
            guard let note = noteLookup[id] else {
                notesToRemove.append(id)
                continue
            }
            
            // Skip hold notes as they're handled separately
            if note.type == .hold {
                continue
            }
            
            let delta = note.time - songTime
            let centerX = laneStartX + CGFloat(note.lane) * laneWidth + laneWidth * 0.5
            let verticalDistance = CGFloat(delta) * noteSpeed
            
            // Apply different paths based on lane count
            let horizontalOffset: CGFloat
            var rotationAngle: CGFloat = 0
            
            if chart.lanes == 3 {
                // 3-lane: notes start close together, spread apart as they fall
                let spreadFactor: CGFloat = 0.04  // Controls spreading angle
                switch note.lane {
                case 0: // Left lane spreads left (away from center)
                    horizontalOffset = -verticalDistance * spreadFactor * 1.75 - 25  // Shifted left
                    // Calculate rotation to follow the path angle
                    rotationAngle = atan2(horizontalOffset, verticalDistance)
                case 2: // Right lane spreads right (away from center)
                    horizontalOffset = -verticalDistance * spreadFactor * 1.0 + 25  // Shifted right more
                    // Calculate rotation to follow the path angle
                    rotationAngle = atan2(horizontalOffset, verticalDistance)
                default: // Middle lane stays straight
                    horizontalOffset = -verticalDistance * spreadFactor * 0.15
                    rotationAngle = 0
                }
            } else {
                // 4-lane: all lanes drift right
                horizontalOffset = verticalDistance * laneAngleFactor
                rotationAngle = 0
            }
            
            // Keep note centered in its lane as it moves down
            node.position = CGPoint(x: centerX + horizontalOffset, y: hitLineY + verticalDistance)
            
            // Apply rotation to sprite nodes (not shape nodes)
            if let spriteNode = node as? SKSpriteNode {
                spriteNode.zRotation = rotationAngle
            }

            if delta < -hitWindow {
                // Note passed the hit line without being hit - show MISS text
                showMissText(at: node.position)
                register(judgement: .miss, for: note, showMissText: false)
            }
        }
        
        // Clean up orphaned notes
        for id in notesToRemove {
            activeNotes[id]?.removeFromParent()
            activeNotes.removeValue(forKey: id)
        }
    }
    
    private func updateHoldNotes(songTime: Double) {
        var holdsToRemove: [UUID] = []
        
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

    private func node(for note: Note) -> SKNode? {
        activeNotes[note.id]
    }

    private func register(judgement: Judgement, for note: Note, showMissText: Bool = false) {
        gameState?.registerHit(judgement)
        
        if let node = activeNotes[note.id] {
            node.removeAllActions()
            
            // Show particle effect based on judgement
            spawnHitParticles(at: node.position, judgement: judgement, lane: note.lane)
            
            // TTR4-style floating judgment text
            showJudgmentText(judgement, at: node.position)
            
            // TTR4-style lane glow on hit
            flashLaneGlow(lane: note.lane, judgement: judgement)

            // Floating hit marker
            spawnHitMarker(judgement, at: node.position)
            
            // Animated removal with scale burst
            let scale = SKAction.scale(to: 1.8, duration: 0.12)
            let fade = SKAction.fadeOut(withDuration: 0.12)
            let group = SKAction.group([fade, scale])
            node.run(group) { node.removeFromParent() }
            activeNotes.removeValue(forKey: note.id)
        }
    }
    
    private func spawnHitParticles(at position: CGPoint, judgement: Judgement, lane: Int) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = SKTexture(imageNamed: "spark")
        
        // Color based on judgement
        let color: SKColor
        let numParticles: Int
        let scale: CGFloat
        switch judgement {
        case .perfect:
            color = SKColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1.0)
            numParticles = 40
            scale = 0.5  // Brighter burst for perfect
        case .great:
            color = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1.0)
            numParticles = 25
            scale = 0.4
        case .good:
            color = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
            numParticles = 18
            scale = 0.3
        case .miss:
            color = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
            numParticles = 12
            scale = 0.2
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
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(imageNamed: "spark")
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
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location, touch: touch, phase: .began)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPausedState else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location, touch: touch, phase: .moved)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPausedState else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location, touch: touch, phase: .ended)
    }

    private func handleTap(at point: CGPoint, touch: UITouch, phase: UITouch.Phase) {
        guard songStartTime != nil else { return }
        guard !isPausedState else { return }
        let songTime = latestSongTime
        let laneWidth = chart.lanes == 3 ? (size.width * 0.7) / CGFloat(chart.lanes) : size.width / CGFloat(chart.lanes)
        let laneStartX = chart.lanes == 3 ? (size.width - size.width * 0.7) / 2 : 0
        let tappedLane = Int((point.x - laneStartX) / laneWidth)
        guard tappedLane >= 0 && tappedLane < chart.lanes else { return }

        switch phase {
        case .began:
            touchedLanes.insert(tappedLane)
            
            // Check for hold notes
            let holdCandidates = notes.filter {
                $0.type == .hold &&
                $0.lane == tappedLane &&
                activeNotes[$0.id] != nil &&
                abs($0.time - songTime) <= hitWindow
            }
            
            if let target = holdCandidates.min(by: {
                abs($0.time - songTime) < abs($1.time - songTime)
            }) {
                activeHolds[target.id] = (songTime, tappedLane)
            }
        case .ended:
            touchedLanes.remove(tappedLane)
            return
        default:
            return
        }
        
        // Find all active tap/shake notes in the tapped lane within hit window
        let candidates = notes.filter { 
            ($0.type == .tap || $0.type == .shake) &&
            $0.lane == tappedLane && 
            activeNotes[$0.id] != nil && 
            abs($0.time - songTime) <= hitWindow 
        }
        
        // Register the closest note in time
        guard let target = candidates.min(by: { 
            abs($0.time - songTime) < abs($1.time - songTime) 
        }) else {
            // No note found - bad tap (penalty without marking a note miss)
            gameState?.registerBadTap()
            return
        }
        
        let delta = abs(target.time - songTime)
        let judgement = getJudgement(for: delta)
        register(judgement: judgement, for: target)
    }
    
    private func getJudgement(for delta: Double) -> Judgement {
        if delta <= 0.06 {
            return .perfect
        } else if delta <= 0.12 {
            return .great
        } else {
            return .good
        }
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
        guard lane >= 0 && lane < laneGlowNodes.count else { return }
        let glowNode = laneGlowNodes[lane]
        
        let intensity: CGFloat
        switch judgement {
        case .perfect: intensity = 0.25
        case .great: intensity = 0.18
        case .good: intensity = 0.12
        case .miss: intensity = 0.08
        }
        
        glowNode.alpha = intensity
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
                    print("Warning: Could not load revenge background: \(imageName)")
                    continue
                }
                
                let bgSprite = SKSpriteNode(texture: SKTexture(image: bgImage))
                bgSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
                bgSprite.size = size
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
            animateRevengeBackground()
        }
    }
    
    private func animateRevengeBackground() {
        guard isRevengeAnimating else { return }
        
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
        let shakeAmount: CGFloat = 10
        let shakeDuration: TimeInterval = 0.05
        
        let moveRight = SKAction.moveBy(x: shakeAmount, y: 0, duration: shakeDuration)
        let moveLeft = SKAction.moveBy(x: -shakeAmount * 2, y: 0, duration: shakeDuration)
        let moveCenter = SKAction.moveBy(x: shakeAmount, y: 0, duration: shakeDuration)
        
        let shakeSequence = SKAction.sequence([moveRight, moveLeft, moveCenter])
        let repeatShake = SKAction.repeat(shakeSequence, count: 3)
        
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
            milestone.position = CGPoint(x: size.width * 0.5, y: size.height * 0.6)
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
            spawnCoinPopup(at: CGPoint(x: size.width * 0.5, y: size.height * 0.55), text: text)
        }
    }
    
    private func animateMultiplierChange(from oldMultiplier: Int, to newMultiplier: Int) {
        if newMultiplier > oldMultiplier {
            // Multiplier increased - celebrate!
            let multiplierText = SKLabelNode(text: "\(newMultiplier)X MULTIPLIER!")
            multiplierText.fontName = "AvenirNext-Heavy"
            multiplierText.fontSize = 36
            multiplierText.fontColor = SKColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 1.0)
            multiplierText.position = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
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
                spawnCoinPopup(at: CGPoint(x: size.width * 0.5, y: size.height * 0.65), text: text)
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
        let flash = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        flash.fillColor = color
        flash.strokeColor = .clear
        flash.zPosition = 150
        flash.alpha = 1.0
        addChild(flash)
        
        let fade = SKAction.fadeOut(withDuration: 0.3)
        flash.run(SKAction.sequence([fade, SKAction.removeFromParent()]))
    }
    
    func checkSongCompletion() {
        guard gameState?.isCompleted == false else { return }
        guard songStartTime != nil else { return }  // Don't check until song has actually started

        let noMoreQueuedNotes = nextNoteIndex >= notes.count
        let noActiveNotes = activeNotes.isEmpty
        let noActiveHolds = activeHolds.isEmpty
        // Account for offset when checking if we're past the last note
        let adjustedLastNoteEndTime = lastNoteEndTime + chart.offset
        let timePastLastNote = latestSongTime >= adjustedLastNoteEndTime + 1.0

        if (noMoreQueuedNotes && noActiveNotes && noActiveHolds) || (timePastLastNote && noActiveNotes && noActiveHolds) {
            DispatchQueue.main.async { [weak self] in
                self?.gameState?.markCompleted()
                self?.audio.stop()
            }
        }
    }

    private var latestSongTime: Double = 0
}
