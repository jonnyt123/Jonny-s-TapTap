import SpriteKit
import SwiftUI
import CoreMotion

final class GameScene: SKScene {
    weak var gameState: GameState?

    private var chart: Chart = ChartLoader.loadChart()
    private var notes: [Note] = []
    private var noteLookup: [UUID: Note] = [:]
    private var nextNoteIndex: Int = 0
    private var activeNotes: [UUID: SKShapeNode] = [:]
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
    private let spawnLeadTime: Double = 2.5
    private let hitWindow: Double = 0.18  // Stricter timing window for better challenge
    private let noteSpeed: CGFloat = 320   // Slightly reduced for smoother movement
    private let hitLineY: CGFloat = 180
    private var lastNoteEndTime: Double = 0

    private let laneColors: [SKColor] = [
        SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),    // Red (lane 0)
        SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1),    // Blue (lane 1)
        SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1),    // Gold (lane 2)
        SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1)     // Green (lane 3)
    ]

    private var revengeOverlayNode: SKSpriteNode?
    private var backgroundNodes: [SKSpriteNode] = []
    private var backgroundAnimationIndex: Int = 0
    private var isAnimatingBackground: Bool = false
    private let backgroundImages = [
        "1d2d6c00-2eb7-46f1-b8bf-fa5495830709.png",
        "2d07ae7e-18bd-433e-a0a2-4aa97650d495.png",
        "A_set_of_digital_illustrations_displays_a_futurist.png",
        "A_set_of_four_transparent_background_PNG_layers_is.png",
        "particles_layer.png"
    ]

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
        isAnimatingBackground = false  // Stop animation loop
        backgroundNodes.removeAll()
        backgroundAnimationIndex = 0
        audio.stop()
        
        // Reset game state FIRST before loading chart
        gameState?.reset()
        
        let chartName = gameState?.songChartName ?? song.chartName
        chart = ChartLoader.loadChart(named: chartName, difficulty: gameState?.difficulty ?? .medium)
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
        // Add animated neon background
        addAnimatedBackground()

        addSpotlights()
        addStarBursts()
        addStageBase()

        // Add subtle vignette on top
        let vignette = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        vignette.fillColor = SKColor.black.withAlphaComponent(0.22)
        vignette.strokeColor = .clear
        vignette.zPosition = 4
        vignette.blendMode = .multiply
        addChild(vignette)
        
        guard chart.lanes > 0 else { return }
        let width = size.width / CGFloat(chart.lanes)
        for lane in 0..<chart.lanes {
            let rect = CGRect(x: CGFloat(lane) * width, y: 0, width: width, height: size.height)
            let node = SKShapeNode(rect: rect)
            node.fillColor = laneColors[lane % laneColors.count].withAlphaComponent(0.18)
            node.strokeColor = SKColor.white.withAlphaComponent(0.12)
            node.lineWidth = 2
            node.glowWidth = 4
            addChild(node)
            
            // Add subtle glow effect at bottom
            let glowRect = CGRect(x: CGFloat(lane) * width + width * 0.1, y: hitLineY - 60, width: width * 0.8, height: 80)
            let glow = SKShapeNode(rect: glowRect, cornerRadius: 20)
            glow.fillColor = laneColors[lane % laneColors.count].withAlphaComponent(0.08)
            glow.strokeColor = .clear
            glow.glowWidth = 15
            addChild(glow)
        }
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
        // Add base neon background images layered with animation
        for (index, imageName) in backgroundImages.enumerated() {
            var bgImage: UIImage?
            
            // Try to load from bundle first (for assets), then from file
            if let image = UIImage(named: imageName) {
                bgImage = image
            } else if let url = Bundle.main.url(forResource: imageName, withExtension: nil),
                      let image = UIImage(contentsOfFile: url.path) {
                bgImage = image
            }
            
            guard let bgImage = bgImage else {
                print("Warning: Could not load background image: \(imageName)")
                continue
            }
            
            let bgSprite = SKSpriteNode(texture: SKTexture(image: bgImage))
            bgSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
            bgSprite.size = size
            bgSprite.zPosition = CGFloat(index - backgroundImages.count)
            bgSprite.alpha = index == 0 ? 1.0 : 0.0
            addChild(bgSprite)
            backgroundNodes.append(bgSprite)
            
            print("Loaded background image: \(imageName) at index \(index)")
        }

        // Animate background transitions
        if !backgroundNodes.isEmpty {
            isAnimatingBackground = true
            animateBackgroundTransition()
        }
    }

    private func animateBackgroundTransition() {
        let delay: TimeInterval = 4.0  // Change image every 4 seconds

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isAnimatingBackground else { return }

            let nextIndex = (self.backgroundAnimationIndex + 1) % self.backgroundNodes.count
            let currentNode = self.backgroundNodes[self.backgroundAnimationIndex]
            let nextNode = self.backgroundNodes[nextIndex]

            let fadeOutAction = SKAction.fadeAlpha(to: 0, duration: 1.0)
            let fadeInAction = SKAction.fadeAlpha(to: 1.0, duration: 1.0)

            currentNode.run(fadeOutAction)
            nextNode.run(fadeInAction)

            self.backgroundAnimationIndex = nextIndex

            // Continue animation loop
            self.animateBackgroundTransition()
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
            buildHitLine()
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
        let laneWidth = size.width / CGFloat(chart.lanes)
        while nextNoteIndex < notes.count && (notes[nextNoteIndex].time - songTime) <= spawnLeadTime {
            let note = notes[nextNoteIndex]
            let centerX = CGFloat(note.lane) * laneWidth + laneWidth * 0.5
            let noteRadius: CGFloat = 24  // Star radius
            
            // Create 3D star note
            let starPath = createStarPath(radius: noteRadius)
            let node = SKShapeNode(path: starPath)
            node.position = CGPoint(x: centerX, y: size.height + 40)
            node.zPosition = 6
            
            // Use lane-specific color for consistency
            let baseColor = laneColors[note.lane % laneColors.count]
            
            node.fillColor = baseColor
            node.strokeColor = baseColor.withAlphaComponent(1.0)
            node.lineWidth = 2.0
            node.glowWidth = 15
            
            // Add 3D depth with darker shadow
            let shadowStar = SKShapeNode(path: starPath)
            shadowStar.fillColor = SKColor.black.withAlphaComponent(0.4)
            shadowStar.strokeColor = .clear
            shadowStar.position = CGPoint(x: 3, y: -3)
            shadowStar.zPosition = -1
            node.addChild(shadowStar)

            // Add a subtle trailing particle for polish
            let trail = particleCache["trail"] ?? createTrailEmitter(color: baseColor)
            particleCache["trail"] = trail
            let emitter = trail.copy() as! SKEmitterNode
            emitter.targetNode = self
            emitter.zPosition = 5
            node.addChild(emitter)
            
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
        let laneWidth = size.width / CGFloat(chart.lanes)
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
            let centerX = CGFloat(note.lane) * laneWidth + laneWidth * 0.5
            node.position = CGPoint(x: centerX, y: hitLineY + CGFloat(delta) * noteSpeed)

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

    private func node(for note: Note) -> SKShapeNode? {
        activeNotes[note.id]
    }

    private func register(judgement: Judgement, for note: Note, showMissText: Bool = false) {
        gameState?.registerHit(judgement)
        
        if let node = activeNotes[note.id] {
            node.removeAllActions()
            
            // Show particle effect based on judgement
            spawnHitParticles(at: node.position, judgement: judgement, lane: note.lane)
            
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
        switch judgement {
        case .perfect:
            color = SKColor(red: 1.0, green: 0.95, blue: 0.3, alpha: 1.0)
            numParticles = 30
        case .great:
            color = SKColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1.0)
            numParticles = 20
        case .good:
            color = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
            numParticles = 15
        case .miss:
            color = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
            numParticles = 10
        }
        
        emitter.particleColor = color
        emitter.particleBirthRate = 0
        emitter.numParticlesToEmit = numParticles
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.3
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 100
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.4
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.5
        emitter.particleBlendMode = .add
        
        addChild(emitter)
        
        // Burst emission then remove
        emitter.run(SKAction.sequence([
            SKAction.run { emitter.particleBirthRate = 1000 },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { emitter.particleBirthRate = 0 },
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ]))
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
        let laneWidth = size.width / CGFloat(chart.lanes)
        let tappedLane = Int(point.x / laneWidth)
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

    private func updateRevengeOverlay(isActive: Bool) {
        // Lazily create overlay
        if revengeOverlayNode == nil {
            let texture = SKTexture(imageNamed: "revenge_overlay")
            if texture.size() != .zero {
                let node = SKSpriteNode(texture: texture)
                node.alpha = 0.0
                node.zPosition = 3  // Behind notes (6) and hit line (5)
                node.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                node.size = size
                node.color = .clear
                node.colorBlendFactor = 0
                addChild(node)
                revengeOverlayNode = node
            } else {
                return  // No texture found; avoid spam
            }
        }
        guard let overlay = revengeOverlayNode else { return }

        // Keep sizing in sync on rotations/resizes
        overlay.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        overlay.size = size

        // Fade overlay
        if isActive {
            if overlay.alpha < 0.25 {
                overlay.removeAllActions()
                overlay.run(SKAction.fadeAlpha(to: 0.25, duration: 0.25))
            }
        } else {
            if overlay.alpha > 0.0 {
                overlay.removeAllActions()
                overlay.run(SKAction.fadeOut(withDuration: 0.25))
            }
        }
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
