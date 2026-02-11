import SpriteKit
import UIKit
import AVFoundation

final class SongSelectScene: SKScene {
    struct NormalizedRect {
        let center: CGPoint
        let size: CGSize
    }

    struct Layout {
        let referenceSize = CGSize(width: 1024, height: 1536)
        let centerCardRect = NormalizedRect(center: CGPoint(x: 0.50, y: 0.58), size: CGSize(width: 0.96, height: 0.78))
        let leftPeekRect = NormalizedRect(center: CGPoint(x: 0.17, y: 0.58), size: CGSize(width: 0.84, height: 0.69))
        let rightPeekRect = NormalizedRect(center: CGPoint(x: 0.83, y: 0.58), size: CGSize(width: 0.84, height: 0.69))
        let backButton = NormalizedRect(center: CGPoint(x: 0.08, y: 0.94), size: CGSize(width: 0.10, height: 0.06))
        let playButton = NormalizedRect(center: CGPoint(x: 0.84, y: 0.12), size: CGSize(width: 0.22, height: 0.08))
    }

    static let backButtonName = "BACK_BUTTON"
    static let playButtonName = "PLAY_BUTTON"

    var songs: [SongMetadata] = [] {
        didSet { rebuildCards() }
    }
    var currentIndex: Int = 0
    var onCurrentSongChanged: ((SongMetadata) -> Void)?
    var onBack: (() -> Void)?
    var onPlayRequested: ((SongMetadata) -> Void)?
    var isSongUnlocked: ((SongMetadata) -> Bool)?

    private let layout = Layout()
    private var songSelectBackground: SKSpriteNode?
    private let songSelectUI = SKNode()
    private let carouselContainer = SKNode()
    private let labelsContainer = SKNode()
    private let buttonsContainer = SKNode()
    private var cardNodes: [SKNode] = []
    private var scrollOffset: CGFloat = 0
    private var targetOffset: CGFloat = 0
    private var isDragging = false
    private var dragStartX: CGFloat = 0
    private var dragStartOffset: CGFloat = 0
    private var velocityX: CGFloat = 0
    private var lastDragTime: TimeInterval = 0
    private var lastDragX: CGFloat = 0
    private var dragDistance: CGFloat = 0
    private var lastReportedIndex: Int = -1
    private var snapTargetIndex: Int?

    private var previewPlayer: AVAudioPlayer?
    private var previewTimer: Timer?
    private var songCardFontName: String?
    private var fadeTimer: Timer?
    private var lastPreviewSongID: String?
    private var missingPreviewSongIDs: Set<String> = []

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black
        setupScene()
        layoutScene()
        rebuildCards()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        if !isDragging {
            if let targetIndex = snapTargetIndex {
                let target = CGFloat(targetIndex - currentIndex)
                let delta = target - scrollOffset
                scrollOffset += delta * 0.18
                if abs(delta) < 0.001 {
                    scrollOffset = 0
                    currentIndex = targetIndex
                    snapTargetIndex = nil
                    reportCurrentSelectionIfNeeded(force: true)
                }
            }
        }
        updateCardTransforms()
        if snapTargetIndex == nil {
            reportCurrentSelectionIfNeeded()
        }
    }

    private func setupScene() {
        if songSelectBackground == nil {
            if let texture = loadBackgroundTexture() {
                let background = SKSpriteNode(texture: texture)
                background.name = "songSelectBackground"
                background.zPosition = -10
                background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                songSelectBackground = background
                addChild(background)
            } else {
                let fallback = SKSpriteNode(color: SKColor.black, size: size)
                fallback.name = "songSelectBackground"
                fallback.zPosition = -10
                fallback.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                songSelectBackground = fallback
                addChild(fallback)
            }
        }

        if songSelectUI.parent == nil {
            songSelectUI.name = "songSelectUI"
            songSelectUI.zPosition = 1
            addChild(songSelectUI)
        }

        if carouselContainer.parent == nil {
            carouselContainer.name = "carouselContainer"
            carouselContainer.zPosition = 2
            songSelectUI.addChild(carouselContainer)
        }

        if labelsContainer.parent == nil {
            labelsContainer.name = "labelsContainer"
            labelsContainer.zPosition = 2
            songSelectUI.addChild(labelsContainer)
        }

        if buttonsContainer.parent == nil {
            buttonsContainer.name = "buttonsContainer"
            buttonsContainer.zPosition = 3
            songSelectUI.addChild(buttonsContainer)
        }

        let back = SKSpriteNode(color: .clear, size: .zero)
        back.name = Self.backButtonName
        back.alpha = 0.001
        back.zPosition = 3
        buttonsContainer.addChild(back)

        let play = SKSpriteNode(color: .clear, size: .zero)
        play.name = Self.playButtonName
        play.alpha = 0.001
        play.zPosition = 3
        buttonsContainer.addChild(play)
    }

    private func layoutScene() {
        guard let background = songSelectBackground else { return }
        let textureSize = background.texture?.size() ?? layout.referenceSize
        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        background.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        background.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

        songSelectUI.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        songSelectUI.setScale(scale)
        let centerRect = resolve(layout.centerCardRect)
        carouselContainer.position = CGPoint(x: centerRect.midX, y: centerRect.midY)
        labelsContainer.position = carouselContainer.position
        buttonsContainer.position = .zero

        let backFrame = resolve(layout.backButton)
        if let back = buttonsContainer.childNode(withName: Self.backButtonName) as? SKSpriteNode {
            back.size = backFrame.size
            back.position = CGPoint(x: backFrame.midX, y: backFrame.midY)
        }
        let playFrame = resolve(layout.playButton)
        if let play = buttonsContainer.childNode(withName: Self.playButtonName) as? SKSpriteNode {
            play.size = playFrame.size
            play.position = CGPoint(x: playFrame.midX, y: playFrame.midY)
        }
        updateCardTransforms()
    }

    private func rebuildCards() {
        carouselContainer.removeAllChildren()
        cardNodes.removeAll()
        guard !songs.isEmpty else { return }

        for song in songs {
            let card = buildCard(for: song)
            carouselContainer.addChild(card)
            cardNodes.append(card)
        }
        currentIndex = max(0, min(songs.count - 1, currentIndex))
        scrollOffset = 0
        targetOffset = 0
        updateCardTransforms()
        reportCurrentSelectionIfNeeded()
    }

    private func buildCard(for song: SongMetadata) -> SKNode {
        let container = SKNode()

        let cardSize = resolve(layout.centerCardRect).size
        let cardTexture = loadCardTexture()
        let card = cardTexture != nil ? SKSpriteNode(texture: cardTexture) : SKSpriteNode(color: SKColor(white: 0.12, alpha: 0.9), size: cardSize)
        card.size = cardSize
        card.zPosition = 1
        card.name = "card"
        container.addChild(card)

        let fontName = loadSongCardFontName() ?? "Apocalypse"
        let title = SKLabelNode(fontNamed: fontName)
        let titleText = song.title.uppercased()
        if titleText.contains("THROUGH THE FIRE AND FLAMES") {
            title.text = "THROUGH THE FIRE\nAND FLAMES"
            title.fontSize = 55
        } else {
            title.text = titleText
            title.fontSize = 79
        }
        title.fontColor = .white
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.zPosition = 2
        title.position = CGPoint(x: 0, y: 0)
        card.addChild(title)

        let artist = SKLabelNode(fontNamed: fontName)
        artist.text = song.artist.isEmpty ? "" : song.artist
        artist.fontSize = 32
        artist.fontColor = SKColor(white: 0.85, alpha: 1.0)
        artist.horizontalAlignmentMode = .center
        artist.verticalAlignmentMode = .center
        artist.zPosition = 2
        artist.position = CGPoint(x: 0, y: -cardSize.height * 0.08)
        card.addChild(artist)

        let availability = ChartLoader.availability(for: song)
        var badgeText = difficultyBadgeText(availability: availability)
        if let isSongUnlocked, !isSongUnlocked(song) {
            badgeText = "LOCKED"
        }
        let badge = SKLabelNode(fontNamed: "Avenir-Heavy")
        badge.text = badgeText
        badge.fontSize = 12
        badge.fontColor = SKColor(red: 0.98, green: 0.7, blue: 0.25, alpha: 1.0)
        badge.horizontalAlignmentMode = .center
        badge.verticalAlignmentMode = .center
        badge.position = CGPoint(x: 0, y: -cardSize.height * 0.36)
        card.addChild(badge)

        if let art = loadAlbumArt(for: song) {
            let artNode = SKSpriteNode(texture: SKTexture(image: art))
            artNode.size = CGSize(width: cardSize.width * 0.78, height: cardSize.height * 0.48)
            artNode.position = CGPoint(x: 0, y: -cardSize.height * 0.22)
            artNode.zPosition = 0
            card.addChild(artNode)
        }

        return container
    }

    private func difficultyBadgeText(availability: Set<Difficulty>) -> String {
        let order: [Difficulty] = [.easy, .medium, .hard, .extreme]
        return order.map { availability.contains($0) ? $0.rawValue.prefix(1) : "-" }.joined(separator: " ")
    }

    private func loadAlbumArt(for song: SongMetadata) -> UIImage? {
        if let image = UIImage(named: "\(song.id)_cover") {
            return image
        }
        if let image = UIImage(named: "album") {
            return image
        }
        return nil
    }

    private func loadSongCardFontName() -> String? {
        if let cached = songCardFontName {
            return cached
        }
        let name = FontRegistrar.registerFont(
            resourceName: "Apocalypse",
            fileExtension: "ttf",
            fallbackPostScriptName: "Apocalypse"
        )
        songCardFontName = name
        return name
    }

    private func loadCardTexture() -> SKTexture? {
        guard let image = UIImage(named: "song_card") else { return nil }
        return SKTexture(image: image)
    }

    private func updateCardTransforms() {
        guard !cardNodes.isEmpty else { return }
        let spacing = abs(resolve(layout.rightPeekRect).midX - resolve(layout.centerCardRect).midX)
        for (index, node) in cardNodes.enumerated() {
            let relative = CGFloat(index - currentIndex) - scrollOffset
            let x = relative * spacing
            node.position = CGPoint(x: x, y: 0)
            let distance = abs(relative)
            let scale = max(0.75, 1.0 - distance * 0.15)
            let alpha = max(0.35, 1.0 - distance * 0.35)
            node.setScale(scale)
            node.alpha = alpha
            node.zPosition = 1000 - distance * 10
        }
    }

    private func reportCurrentSelectionIfNeeded(force: Bool = false) {
        let nearest = max(0, min(cardNodes.count - 1, currentIndex))
        guard force || nearest != lastReportedIndex else { return }
        lastReportedIndex = nearest
        if nearest < songs.count {
            onCurrentSongChanged?(songs[nearest])
            startPreviewIfNeeded(for: songs[nearest])
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: buttonsContainer)
        if let back = buttonsContainer.childNode(withName: Self.backButtonName),
           back.contains(location) {
            onBack?()
            return
        }
        if let play = buttonsContainer.childNode(withName: Self.playButtonName),
           play.contains(location) {
            if currentIndex < songs.count {
                let song = songs[currentIndex]
                if isSongUnlocked?(song) != false {
                    onPlayRequested?(song)
                }
            }
            return
        }
        isDragging = true
        dragStartX = touch.location(in: songSelectUI).x
        dragStartOffset = scrollOffset
        dragDistance = 0
        lastDragX = dragStartX
        lastDragTime = touch.timestamp
        velocityX = 0
        snapTargetIndex = nil
        stopPreview()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first else { return }
        let x = touch.location(in: songSelectUI).x
        let delta = x - dragStartX
        let spacing = abs(resolve(layout.rightPeekRect).midX - resolve(layout.centerCardRect).midX)
        scrollOffset = dragStartOffset - delta / spacing
        dragDistance += abs(delta - (lastDragX - dragStartX))
        lastDragX = x
        lastDragTime = touch.timestamp
        velocityX = delta
        updateCardTransforms()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        finishDrag(with: touch)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        finishDrag(with: touch)
    }

    private func finishDrag(with touch: UITouch) {
        isDragging = false
        let spacing = abs(resolve(layout.rightPeekRect).midX - resolve(layout.centerCardRect).midX)
        let deltaX = touch.location(in: songSelectUI).x - lastDragX
        let deltaT = max(0.001, CGFloat(touch.timestamp - lastDragTime))
        let velocity = deltaX / deltaT
        let projected = scrollOffset - velocity * 0.18 / spacing
        let snapped = Int(round(CGFloat(currentIndex) + projected))
        let clamped = max(0, min(cardNodes.count - 1, snapped))
        snapTargetIndex = clamped
        targetOffset = CGFloat(clamped - currentIndex)

        if dragDistance < 12, abs(scrollOffset) < 0.15 {
            if currentIndex < songs.count {
                let song = songs[currentIndex]
                if isSongUnlocked?(song) != false {
                    onPlayRequested?(song)
                }
            }
        }
    }

    private func resolve(_ normalized: NormalizedRect) -> CGRect {
        let size = CGSize(width: normalized.size.width * layout.referenceSize.width,
                          height: normalized.size.height * layout.referenceSize.height)
        let center = point(from: normalized.center)
        return CGRect(x: center.x - size.width * 0.5,
                      y: center.y - size.height * 0.5,
                      width: size.width,
                      height: size.height)
    }

    private func point(from normalized: CGPoint) -> CGPoint {
        let x = (normalized.x - 0.5) * layout.referenceSize.width
        let y = (normalized.y - 0.5) * layout.referenceSize.height
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        if value < min { return min }
        if value > max { return max }
        return value
    }

    private func loadBackgroundTexture() -> SKTexture? {
        guard let image = UIImage(named: "song_select_background") else {
            debugLog("⚠️ Missing song_select_background asset in catalog.")
            return nil
        }
        return SKTexture(image: image)
    }

    private func startPreviewIfNeeded(for song: SongMetadata) {
        if lastPreviewSongID == song.id { return }
        lastPreviewSongID = song.id
        startPreview(for: song)
    }

    private func startPreview(for song: SongMetadata) {
        stopPreview()
        guard let url = resolvePreviewURL(for: song) else {
            if !missingPreviewSongIDs.contains(song.id) {
                missingPreviewSongIDs.insert(song.id)
                debugLog("⚠️ Preview missing for \(song.audioName).\(song.audioExtension)")
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                let previewLength = 20.0
                let maxStart = max(0, player.duration - previewLength)
                let startTime = maxStart > 0 ? Double.random(in: 0...maxStart) : 0
                player.currentTime = startTime
                player.volume = 0.0
                player.prepareToPlay()
                DispatchQueue.main.async {
                    self.previewPlayer = player
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                    } catch {
                        // Ignore audio session errors for previews.
                    }
                    player.play()
                    self.fade(player: player, to: 0.7, duration: 0.2)
                    self.previewTimer = Timer.scheduledTimer(withTimeInterval: previewLength, repeats: false) { [weak self] _ in
                        self?.stopPreview()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.previewPlayer = nil
                }
            }
        }
    }

    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        fadeTimer?.invalidate()
        fadeTimer = nil
        guard let player = previewPlayer else { return }
        fade(player: player, to: 0.0, duration: 0.2) {
            player.stop()
        }
        previewPlayer = nil
    }

    private func fade(player: AVAudioPlayer, to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let steps = 10
        let stepTime = duration / Double(steps)
        let startVolume = player.volume
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepTime, repeats: true) { timer in
            step += 1
            let t = Float(step) / Float(steps)
            player.volume = startVolume + (target - startVolume) * t
            if step >= steps {
                timer.invalidate()
                completion?()
            }
        }
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

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        stopPreview()
    }
}
