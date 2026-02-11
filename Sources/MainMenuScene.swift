import SpriteKit
import UIKit

final class MainMenuScene: SKScene {

    /// When false, avatar idle animations (rock/sway/pulse) are not run. Avatar remains a static image. Set to true to re-enable if animation code is restored.
    private static let avatarIdleAnimationEnabled = false

    private enum StatsHUDLayout {
        static let usernameOffset = CGPoint(x: -86.7, y: 193.9)
        static let levelOffset = CGPoint(x: -98.3, y: 108.8)
        static let coinsOffset = CGPoint(x: -98.3, y: 11.0)
        static let usernameTopInset: CGFloat = 5.7
    }

    struct NormalizedRect {
        let center: CGPoint
        let size: CGSize
    }

    struct MenuLayout {
        let referenceSize = CGSize(width: 1024, height: 1536)
        let headerRect = NormalizedRect(center: CGPoint(x: 0.20, y: 0.93), size: CGSize(width: 0.32, height: 0.05))
        let avatarRect = NormalizedRect(center: CGPoint(x: 0.26, y: 0.58), size: CGSize(width: 0.40, height: 0.36))
        let avatarSlotRect = NormalizedRect(center: CGPoint(x: 0.26, y: 0.58), size: CGSize(width: 0.36, height: 0.32))
        let statsRect = NormalizedRect(center: CGPoint(x: 0.72, y: 0.60), size: CGSize(width: 0.42, height: 0.26))
        let coinsRect = NormalizedRect(center: CGPoint(x: 0.72, y: 0.60), size: CGSize(width: 0.42, height: 0.26))
        let storeButton = NormalizedRect(center: CGPoint(x: 0.80, y: 0.52), size: CGSize(width: 0.20, height: 0.07))
        let playButton = NormalizedRect(center: CGPoint(x: 0.50, y: 0.14), size: CGSize(width: 0.56, height: 0.12))
        let beatmapEditorButton = NormalizedRect(center: CGPoint(x: 0.60, y: 0.33), size: CGSize(width: 0.22, height: 0.07))
        let userBeatmapsButton = NormalizedRect(center: CGPoint(x: 0.82, y: 0.33), size: CGSize(width: 0.22, height: 0.07))
        let settingsButton = NormalizedRect(center: CGPoint(x: 0.72, y: 0.26), size: CGSize(width: 0.46, height: 0.07))
        let usernameValueRect = NormalizedRect(center: CGPoint(x: 0.20, y: 0.93), size: CGSize(width: 0.34, height: 0.06))
        let levelTitleRect = NormalizedRect(center: CGPoint(x: 0.60, y: 0.69), size: CGSize(width: 0.18, height: 0.06))
        let levelValueRect = NormalizedRect(center: CGPoint(x: 0.788, y: 0.586), size: CGSize(width: 0.18, height: 0.06))
        let usernameAboveLevelRect = NormalizedRect(center: CGPoint(x: 0.57, y: 0.626), size: CGSize(width: 0.42, height: 0.08))
        let coinsTitleRect = NormalizedRect(center: CGPoint(x: 0.60, y: 0.58), size: CGSize(width: 0.18, height: 0.05))
        let coinsValueRect = NormalizedRect(center: CGPoint(x: 0.72, y: 0.58), size: CGSize(width: 0.20, height: 0.05))
    }

    static let playButtonName = "PLAY_BUTTON"
    static let settingsButtonName = "SETTINGS_BUTTON"
    static let beatmapEditorButtonName = "BEATMAP_EDITOR_BUTTON"
    static let userBeatmapsButtonName = "USER_BEATMAPS_BUTTON"
    static let avatarButtonName = "AVATAR_BUTTON"
    static let storeButtonName = "STORE_BUTTON"

    var onPlayTapped: (() -> Void)?
    var onMultiplayerTapped: (() -> Void)?
    var onShopTapped: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onAvatarTapped: (() -> Void)?
    var onBeatmapEditorTapped: (() -> Void)?
    var onUserBeatmapsTapped: (() -> Void)?

    var safeAreaInsets: UIEdgeInsets = .zero

    private let layout = MenuLayout()
    private var menuBackground: SKSpriteNode?
    private let mainMenuUI = SKNode()
    private var buttonNodes: [String: SKSpriteNode] = [:]
    private var pressedButtonName: String?
    private let headerPanel = SKSpriteNode()
    private let avatarPanel = SKSpriteNode()
    private let statsPanel = SKSpriteNode()
    private let statsHUDContainer = SKNode()
    private let coinsPanel = SKSpriteNode()
    private let playPanel = SKSpriteNode()
    private let usernameLabel = SKLabelNode()
    private let levelValueText = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let coinsValueText = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let playLabel = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let settingsIconLabel = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let beatmapEditorLabel = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let userBeatmapsLabel = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let storeTitleLabel = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let storeSubtitleLabel = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
    private let beatmapButtonPanel = SKSpriteNode()
    private let userBeatmapsButtonPanel = SKSpriteNode()
    private let settingsButtonPanel = SKSpriteNode()
    private var arcDividers: [SKSpriteNode] = []
    private var avatarCropNode: SKCropNode?
    private var avatarNode: SKSpriteNode?
    /// Overlay sprite on top of base avatar; shows current gender. Still image, no actions.
    private var avatarOverlayNode: SKSpriteNode?
    /// Stable key so we refresh overlay when gender changes (SpriteKit caches textures).
    private var lastAvatarOverlayKey: String?
    private var patchNodes: [String: SKSpriteNode] = [:]
    private let enableFontDebugLabel = false
    private var lastUsernameText: String?
    private var lastLevelText: String?
    private var lastCoinsText: String?
    private var usernameFontName: String?
    private static let coinsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black
        setupScene()
        refreshAvatarDisplay()
        layoutScene()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        avatarNode?.removeAllActions()
        avatarOverlayNode?.removeAllActions()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    func updatePlayerData(username: String, level: Int, coins: Int, avatarImage: UIImage?) {
        refreshMainMenuHUD(username: username, level: level, coins: coins)
        ensureAvatarNodeExists()
        ensureAvatarOverlayExists()
        refreshAvatarDisplay()
    }

    private func setupScene() {
        if menuBackground == nil {
            if let texture = loadBackgroundTexture() {
                let background = SKSpriteNode(texture: texture)
                background.name = "menuBackground"
                background.zPosition = -10
                background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                menuBackground = background
                addChild(background)
            } else {
                let fallback = SKSpriteNode(color: .black, size: layout.referenceSize)
                fallback.name = "menuBackground"
                fallback.zPosition = -10
                fallback.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                menuBackground = fallback
                addChild(fallback)
            }
        }

        if mainMenuUI.parent == nil {
            mainMenuUI.name = "mainMenuUI"
            mainMenuUI.zPosition = 1
            addChild(mainMenuUI)
        }
        if statsHUDContainer.parent == nil {
            statsHUDContainer.name = "statsHUDContainer"
            statsHUDContainer.alpha = 1.0
            statsHUDContainer.zPosition = 10
            mainMenuUI.addChild(statsHUDContainer)
        }

        if buttonNodes.isEmpty {
            addButtonNode(name: Self.playButtonName)
            addButtonNode(name: Self.settingsButtonName)
            addButtonNode(name: Self.avatarButtonName)
            addButtonNode(name: Self.beatmapEditorButtonName)
            addButtonNode(name: Self.userBeatmapsButtonName)
            addButtonNode(name: Self.storeButtonName)
        }

        if headerPanel.parent == nil {
            configurePanel(headerPanel, fill: SKColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 0.35))
            mainMenuUI.addChild(headerPanel)
        }

        if avatarPanel.parent == nil {
            configurePanel(avatarPanel, fill: SKColor(red: 0.08, green: 0.02, blue: 0.02, alpha: 0.40))
            mainMenuUI.addChild(avatarPanel)
        }

        if statsPanel.parent == nil {
            configurePanel(statsPanel, fill: SKColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 0.40))
            mainMenuUI.addChild(statsPanel)
        }

        if coinsPanel.parent == nil {
            configurePanel(coinsPanel, fill: SKColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 0.40))
            mainMenuUI.addChild(coinsPanel)
        }

        if playPanel.parent == nil {
            // Play panel removed; background button remains clickable via hit zone.
        }

        if usernameLabel.parent == nil {
            usernameLabel.fontName = loadUsernameFontName() ?? "Apocalypse Grunge Alt"
            usernameLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            usernameLabel.zPosition = 3.0
            statsHUDContainer.addChild(usernameLabel)
        }

        if levelValueText.parent == nil {
            levelValueText.text = "1"
            levelValueText.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            levelValueText.horizontalAlignmentMode = .left
            levelValueText.verticalAlignmentMode = .center
            levelValueText.zPosition = 3.0
            statsHUDContainer.addChild(levelValueText)
        }

        if coinsValueText.parent == nil {
            coinsValueText.text = "0"
            coinsValueText.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            coinsValueText.horizontalAlignmentMode = .right
            coinsValueText.verticalAlignmentMode = .center
            coinsValueText.zPosition = 3.0
            statsHUDContainer.addChild(coinsValueText)
        }

        if playLabel.parent == nil {
            // Play label removed; background button remains clickable via hit zone.
        }

        if settingsIconLabel.parent == nil {
            settingsIconLabel.text = "SETTINGS"
            settingsIconLabel.fontSize = 22
            settingsIconLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            settingsIconLabel.horizontalAlignmentMode = .center
            settingsIconLabel.verticalAlignmentMode = .center
            settingsIconLabel.zPosition = 3.0
            settingsIconLabel.alpha = 0.0
            mainMenuUI.addChild(settingsIconLabel)
        }

        if storeTitleLabel.parent == nil {
            storeTitleLabel.text = "RYTHMTAP"
            storeTitleLabel.fontSize = 20
            storeTitleLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            storeTitleLabel.horizontalAlignmentMode = .center
            storeTitleLabel.verticalAlignmentMode = .center
            storeTitleLabel.zPosition = 3.0
            storeTitleLabel.alpha = 0.0
            mainMenuUI.addChild(storeTitleLabel)
        }

        if storeSubtitleLabel.parent == nil {
            storeSubtitleLabel.text = "STORE"
            storeSubtitleLabel.fontSize = 20
            storeSubtitleLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            storeSubtitleLabel.horizontalAlignmentMode = .center
            storeSubtitleLabel.verticalAlignmentMode = .center
            storeSubtitleLabel.zPosition = 3.0
            storeSubtitleLabel.alpha = 0.0
            mainMenuUI.addChild(storeSubtitleLabel)
        }

        if beatmapEditorLabel.parent == nil {
            beatmapEditorLabel.text = "BEATMAP EDITOR"
            beatmapEditorLabel.fontSize = 22
            beatmapEditorLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            beatmapEditorLabel.horizontalAlignmentMode = .center
            beatmapEditorLabel.verticalAlignmentMode = .center
            beatmapEditorLabel.zPosition = 3.0
            beatmapEditorLabel.alpha = 0.0
            mainMenuUI.addChild(beatmapEditorLabel)
        }

        if userBeatmapsLabel.parent == nil {
            userBeatmapsLabel.text = "USER BEATMAPS"
            userBeatmapsLabel.fontSize = 22
            userBeatmapsLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1.0)
            userBeatmapsLabel.horizontalAlignmentMode = .center
            userBeatmapsLabel.verticalAlignmentMode = .center
            userBeatmapsLabel.zPosition = 3.0
            userBeatmapsLabel.alpha = 0.0
            mainMenuUI.addChild(userBeatmapsLabel)
        }

        if beatmapButtonPanel.parent == nil {
            configureButtonPanel(beatmapButtonPanel)
            mainMenuUI.addChild(beatmapButtonPanel)
        }
        if userBeatmapsButtonPanel.parent == nil {
            configureButtonPanel(userBeatmapsButtonPanel)
            mainMenuUI.addChild(userBeatmapsButtonPanel)
        }
        if settingsButtonPanel.parent == nil {
            configureButtonPanel(settingsButtonPanel)
            mainMenuUI.addChild(settingsButtonPanel)
        }
        if arcDividers.isEmpty {
            for _ in 0..<2 {
                let divider = SKSpriteNode(color: SKColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 0.0), size: .zero)
                divider.zPosition = 2.5
                mainMenuUI.addChild(divider)
                arcDividers.append(divider)
            }
        }

        if avatarCropNode == nil {
            let crop = SKCropNode()
            crop.maskNode = nil
            crop.zPosition = 1.2
            mainMenuUI.addChild(crop)
            avatarCropNode = crop
        }
        if avatarNode == nil, let crop = avatarCropNode {
            let texture = AvatarStore.shared.currentAvatarTexture()
            let sprite = SKSpriteNode(texture: texture)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.zPosition = 1
            crop.addChild(sprite)
            avatarNode = sprite
        }
        if avatarOverlayNode == nil, let crop = avatarCropNode {
            let overlay = SKSpriteNode(texture: AvatarStore.shared.currentAvatarTexture())
            overlay.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            overlay.zPosition = 2
            overlay.name = "avatarOverlay"
            crop.addChild(overlay)
            avatarOverlayNode = overlay
            lastAvatarOverlayKey = AvatarStore.shared.gender.rawValue
        }

        if patchNodes.isEmpty {
            // Removed placeholder patches.
        }

        if enableFontDebugLabel {
            let test = SKLabelNode(fontNamed: "DeathMetalBold.fnt")
            test.text = "FONT OK 123"
            test.fontSize = 48
            test.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            test.zPosition = 9999
            addChild(test)
        }
    }

    private func addButtonNode(name: String) {
        let node = SKSpriteNode(color: .clear, size: .zero)
        node.name = name
        node.alpha = 0.001
        node.zPosition = 2
        mainMenuUI.addChild(node)
        buttonNodes[name] = node
    }

    private func layoutScene() {
        guard let background = menuBackground else { return }
        let referenceSize = layout.referenceSize
        let textureSize = background.texture?.size() ?? referenceSize
        let baseScale = max(size.width / referenceSize.width, size.height / referenceSize.height)
        let scaleBoost: CGFloat = 2.0
        let inset: CGFloat = 8.0
        let shrinkX = (referenceSize.width - inset * 2.0) / referenceSize.width
        let shrinkY = (referenceSize.height - inset * 2.0) / referenceSize.height
        let scale = baseScale * min(shrinkX, shrinkY)
        background.size = CGSize(width: textureSize.width * baseScale * 0.70 + 14.0 + scaleBoost,
                                 height: textureSize.height * baseScale + scaleBoost)
        background.position = CGPoint(x: size.width * 0.5 - 3.0, y: size.height * 0.5)

        mainMenuUI.position = CGPoint(x: size.width * 0.5 + 5.0, y: size.height * 0.5)
        let uiScaleBoost = 1.0 + (scaleBoost / max(referenceSize.width, 1.0))
        mainMenuUI.setScale(scale * uiScaleBoost)

        applyLayout(for: layout.playButton, to: buttonNodes[Self.playButtonName])
        applyLayout(for: layout.settingsButton, to: buttonNodes[Self.settingsButtonName])
        applyLayout(for: layout.avatarRect, to: buttonNodes[Self.avatarButtonName])
        applyLayout(for: layout.beatmapEditorButton, to: buttonNodes[Self.beatmapEditorButtonName])
        applyLayout(for: layout.userBeatmapsButton, to: buttonNodes[Self.userBeatmapsButtonName])
        applyLayout(for: layout.storeButton, to: buttonNodes[Self.storeButtonName])

        layoutPanel(headerPanel, rect: layout.headerRect)
        layoutPanel(avatarPanel, rect: layout.avatarRect)
        layoutPanel(statsPanel, rect: layout.statsRect)
        layoutStatsHUD()
        layoutPanel(coinsPanel, rect: layout.coinsRect)
        if let crop = avatarCropNode, let avatar = avatarNode {
            let slotFrame = rect(from: layout.avatarSlotRect)
            crop.position = CGPoint(x: slotFrame.midX, y: slotFrame.midY)
            crop.setScale(1.0)
            avatar.size = slotFrame.size
            avatar.position = .zero
        }
        if let overlay = avatarOverlayNode {
            let slotFrame = rect(from: layout.avatarSlotRect)
            overlay.size = slotFrame.size
            overlay.position = .zero
        }

        // Play label removed; keep button hit zone only.
        settingsIconLabel.position = CGPoint(x: rect(from: layout.settingsButton).midX, y: rect(from: layout.settingsButton).midY)
        beatmapEditorLabel.position = CGPoint(x: rect(from: layout.beatmapEditorButton).midX, y: rect(from: layout.beatmapEditorButton).midY)
        userBeatmapsLabel.position = CGPoint(x: rect(from: layout.userBeatmapsButton).midX, y: rect(from: layout.userBeatmapsButton).midY)
        let storeFrame = rect(from: layout.storeButton)
        storeTitleLabel.position = CGPoint(x: storeFrame.midX, y: storeFrame.midY + 10.0)
        storeSubtitleLabel.position = CGPoint(x: storeFrame.midX, y: storeFrame.midY - 12.0)

        layoutPanel(beatmapButtonPanel, rect: layout.beatmapEditorButton)
        layoutPanel(userBeatmapsButtonPanel, rect: layout.userBeatmapsButton)
        layoutPanel(settingsButtonPanel, rect: layout.settingsButton)

        let beatmapFrame = rect(from: layout.beatmapEditorButton)
        let userFrame = rect(from: layout.userBeatmapsButton)
        let settingsFrame = rect(from: layout.settingsButton)
        if arcDividers.count == 2 {
            let dividerHeight = beatmapFrame.height * 0.7
            arcDividers[0].size = CGSize(width: 2.0, height: dividerHeight)
            arcDividers[0].position = CGPoint(x: (beatmapFrame.maxX + userFrame.minX) * 0.5,
                                              y: beatmapFrame.midY)
            arcDividers[1].size = CGSize(width: 2.0, height: dividerHeight)
            arcDividers[1].position = CGPoint(x: (userFrame.maxX + settingsFrame.minX) * 0.5,
                                              y: userFrame.midY)
        }
    }

    private func addPatchNode(name: String) {
        let node = SKSpriteNode(color: SKColor(white: 0.08, alpha: 0.85), size: .zero)
        node.name = name
        node.zPosition = 1.5
        mainMenuUI.addChild(node)
        patchNodes[name] = node
    }

    private func configurePanel(_ node: SKSpriteNode, fill: SKColor) {
        node.color = fill
        node.colorBlendFactor = 1.0
        node.zPosition = 1.1
        node.alpha = 0.0
    }

    private func loadUsernameFontName() -> String? {
        if let name = usernameFontName {
            return name
        }
        let name = FontRegistrar.registerFont(
            resourceName: "Apocalypse Grunge Alt",
            fileExtension: "ttf",
            fallbackPostScriptName: "Apocalypse Grunge Alt"
        )
        usernameFontName = name
        return name
    }

    private func configureButtonPanel(_ node: SKSpriteNode) {
        node.color = SKColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 0.55)
        node.colorBlendFactor = 1.0
        node.zPosition = 2.0
        node.alpha = 0.0
    }

    private func layoutPanel(_ node: SKSpriteNode, rect: NormalizedRect) {
        let frame = self.rect(from: rect)
        node.size = frame.size
        node.position = CGPoint(x: frame.midX, y: frame.midY)
        // No border overlay.
    }

    private func layoutStatsHUD() {
        statsHUDContainer.position = statsPanel.position
        statsHUDContainer.zPosition = 999
        statsHUDContainer.setScale(1.0)

        let panelHeight = statsPanel.size.height

        usernameLabel.horizontalAlignmentMode = .center
        usernameLabel.verticalAlignmentMode = .top
        usernameLabel.position = CGPoint(
            x: StatsHUDLayout.usernameOffset.x,
            y: (panelHeight / 2) - StatsHUDLayout.usernameTopInset
        )

        levelValueText.horizontalAlignmentMode = .left
        levelValueText.verticalAlignmentMode = .center
        levelValueText.position = StatsHUDLayout.levelOffset

        coinsValueText.horizontalAlignmentMode = .left
        coinsValueText.verticalAlignmentMode = .center
        coinsValueText.position = StatsHUDLayout.coinsOffset
    }

    private func layoutPatch(_ name: String, rect: NormalizedRect) {
        guard let node = patchNodes[name] else { return }
        let frame = self.rect(from: rect)
        node.size = frame.size
        node.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func loadBackgroundTexture() -> SKTexture? {
        if let image = UIImage(named: "main_menu_background") {
            return SKTexture(image: image)
        }
        if let path = Bundle.main.path(forResource: "main_menu_background", ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return SKTexture(image: image)
        }
        if let resourcesBundle = Bundle.main.url(forResource: "Resources", withExtension: "bundle") {
            let bundlePath = resourcesBundle.appendingPathComponent("main_menu_background.png")
            if FileManager.default.fileExists(atPath: bundlePath.path),
               let image = UIImage(contentsOfFile: bundlePath.path) {
                return SKTexture(image: image)
            }
        }
        let devPath = "/Users/jonny/RhythmTap/RhythmTap/Resources/main_menu_background.png"
        if FileManager.default.fileExists(atPath: devPath),
           let image = UIImage(contentsOfFile: devPath) {
            return SKTexture(image: image)
        }
        debugLog("⚠️ Missing main_menu_background.png")
        return nil
    }

    private func rect(from normalized: NormalizedRect) -> CGRect {
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

    private func applyLayout(for rect: NormalizedRect, to node: SKSpriteNode?) {
        guard let node else { return }
        let frame = self.rect(from: rect)
        node.size = frame.size
        node.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func refreshMainMenuHUD(username: String, level: Int, coins: Int) {
        let clampedUsername = truncateUsername(username.isEmpty ? "PLAYER" : username, maxLength: 14)
        let levelText = "\(max(level, 1))"
        let coinsValue = max(coins, 0)
        let coinsText = Self.coinsFormatter.string(from: NSNumber(value: coinsValue)) ?? "\(coinsValue)"
        if lastUsernameText != clampedUsername {
            usernameLabel.text = clampedUsername
            lastUsernameText = clampedUsername
        }
        if lastLevelText != levelText {
            levelValueText.text = levelText
            lastLevelText = levelText
        }
        if lastCoinsText != coinsText {
            coinsValueText.text = coinsText
            lastCoinsText = coinsText
        }
    }

    private func ensureAvatarNodeExists() {
        guard avatarNode == nil, let crop = avatarCropNode else { return }
        let texture = AvatarStore.shared.currentAvatarTexture()
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.zPosition = 1
        crop.addChild(sprite)
        avatarNode = sprite
    }

    private func ensureAvatarOverlayExists() {
        guard avatarOverlayNode == nil, let crop = avatarCropNode else { return }
        let overlay = SKSpriteNode(texture: AvatarStore.shared.currentAvatarTexture())
        overlay.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        overlay.zPosition = 2
        overlay.name = "avatarOverlay"
        crop.addChild(overlay)
        avatarOverlayNode = overlay
        lastAvatarOverlayKey = AvatarStore.shared.gender.rawValue
    }

    private func refreshAvatarDisplay() {
        avatarNode?.removeAllActions()
        guard let overlay = avatarOverlayNode else { return }
        overlay.removeAllActions()
        let overlayKey = AvatarStore.shared.gender.rawValue
        if lastAvatarOverlayKey == overlayKey {
            return
        }
        let image = AvatarStore.shared.currentAvatarImage()
        overlay.texture = SKTexture(image: image)
        lastAvatarOverlayKey = overlayKey
    }

    private func truncateUsername(_ name: String, maxLength: Int) -> String {
        guard name.count > maxLength else { return name }
        let endIndex = name.index(name.startIndex, offsetBy: max(0, maxLength - 3))
        return String(name[..<endIndex]) + "..."
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: mainMenuUI)
        if let node = hitTestButton(at: location) {
            pressedButtonName = node.name
            node.setScale(0.96)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { resetPressedButton() }
        guard let touch = touches.first else { return }
        let location = touch.location(in: mainMenuUI)
        guard let node = hitTestButton(at: location),
              node.name == pressedButtonName else { return }
        triggerButtonAction(named: node.name)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetPressedButton()
    }

    private func hitTestButton(at location: CGPoint) -> SKSpriteNode? {
        let nodesAtPoint = mainMenuUI.nodes(at: location)
        return nodesAtPoint.first { node in
            guard let name = node.name else { return false }
            return buttonNodes[name] != nil
        } as? SKSpriteNode
    }

    private func triggerButtonAction(named name: String?) {
        switch name {
        case Self.playButtonName:
            onPlayTapped?()
        case Self.settingsButtonName:
            onSettingsTapped?()
        case Self.storeButtonName:
            onShopTapped?()
        case Self.beatmapEditorButtonName:
            onBeatmapEditorTapped?()
        case Self.userBeatmapsButtonName:
            onUserBeatmapsTapped?()
        case Self.avatarButtonName:
            onAvatarTapped?()
        default:
            break
        }
    }

    private func resetPressedButton() {
        if let name = pressedButtonName, let node = buttonNodes[name] {
            node.setScale(1.0)
        }
        pressedButtonName = nil
    }
}
