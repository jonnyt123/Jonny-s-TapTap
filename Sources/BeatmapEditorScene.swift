import SpriteKit

final class BeatmapEditorScene: SKScene {
    var lanes: Int = 4 {
        didSet { lanes = max(3, min(4, lanes)) }
    }
    weak var recorder: BeatmapRecorder?
    weak var editorAudioEngine: EditorAudioEngine?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        view.isMultipleTouchEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine = editorAudioEngine else { return }
        let tMs = engine.currentRawSongMs()
        for touch in touches {
            let loc = touch.location(in: self)
            let lane = laneIndex(forX: loc.x)
            recorder?.recordTap(tMs: tMs, lane: lane)
            flashLane(lane)
        }
    }

    private func laneIndex(forX x: CGFloat) -> Int {
        let laneWidth = size.width / CGFloat(lanes)
        let idx = Int(x / laneWidth)
        return max(0, min(lanes - 1, idx))
    }

    private func flashLane(_ lane: Int) {
        let laneWidth = size.width / CGFloat(lanes)
        let rect = CGRect(x: laneWidth * CGFloat(lane), y: 0, width: laneWidth, height: size.height)
        let node = SKShapeNode(rect: rect)
        node.fillColor = .white.withAlphaComponent(0.12)
        node.strokeColor = .clear
        node.zPosition = 10
        addChild(node)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        node.run(fade) { node.removeFromParent() }
    }
}
