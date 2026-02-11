import SpriteKit
import UIKit

final class TextureManager {
    static let shared = TextureManager()

    private var textures: [String: SKTexture] = [:]
    private var availability: [String: Bool] = [:]

    func preloadForGame() {
        let names = [
            "note_blue_4lane", "note_green_4lane", "note_orange_4lane", "note_red_4lane",
            "note_blue", "note_pink", "note_green",
            "note_metal", "note_metal_blue", "note_metal_pink", "note_metal_green",
            "spark",
            "gameplay_background", "gameplay_background_4lane"
        ]
        preload(names: names)
    }

    func preload(names: [String]) {
        for name in names {
            _ = texture(named: name)
        }
    }

    func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] {
            return cached
        }
        guard let texture = loadTexture(named: name) else {
            availability[name] = false
            return nil
        }
        textures[name] = texture
        availability[name] = true
        return texture
    }

    func hasTexture(named name: String) -> Bool {
        if let cached = availability[name] {
            return cached
        }
        let exists = UIImage(named: name) != nil || Bundle.main.path(forResource: name, ofType: "png") != nil
        availability[name] = exists
        return exists
    }

    func solidColorTexture(color: SKColor) -> SKTexture {
        let rgba = colorKey(color)
        let key = "solid_\(rgba)"
        if let cached = textures[key] {
            return cached
        }
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        let texture = SKTexture(image: image)
        textures[key] = texture
        return texture
    }

    private func loadTexture(named name: String) -> SKTexture? {
        if let image = UIImage(named: name) {
            return SKTexture(image: image)
        }
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return SKTexture(image: image)
        }
        return nil
    }

    private func colorKey(_ color: SKColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ir = Int((r * 255).rounded())
        let ig = Int((g * 255).rounded())
        let ib = Int((b * 255).rounded())
        let ia = Int((a * 255).rounded())
        return "\(ir)_\(ig)_\(ib)_\(ia)"
    }
}
