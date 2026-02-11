import SpriteKit
import UIKit

/// Minimal avatar scene kept for compatibility. AvatarCreatorView now uses SwiftUI-only UI.
/// If presented directly, shows current avatar and a Done button; no customization.
final class AvatarCreatorScene: SKScene {
    private let previewNode = SKSpriteNode()
    private let doneLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
    var onClose: (() -> Void)?

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black
        if previewNode.parent == nil {
            previewNode.zPosition = 1
            addChild(previewNode)
        }
        if doneLabel.parent == nil {
            doneLabel.text = "DONE"
            doneLabel.fontSize = 20
            doneLabel.fontColor = .white
            doneLabel.horizontalAlignmentMode = .center
            doneLabel.verticalAlignmentMode = .center
            doneLabel.zPosition = 2
            addChild(doneLabel)
        }
        layoutScene()
        refreshPreview()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    private func layoutScene() {
        let config = AvatarStore.shared.loadConfig()
        let texture = AvatarStore.shared.renderAvatarTexture(config: config)
        previewNode.texture = texture
        previewNode.size = CGSize(width: min(size.width, size.height) * 0.4, height: min(size.width, size.height) * 0.4)
        previewNode.position = CGPoint(x: size.width * 0.5, y: size.height * 0.6)
        doneLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.2)
    }

    private func refreshPreview() {
        let config = AvatarStore.shared.loadConfig()
        previewNode.texture = AvatarStore.shared.renderAvatarTexture(config: config)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if doneLabel.contains(location) {
            onClose?()
        }
    }
}
