import SpriteKit

extension SKTexture {
    convenience init(imageNamed name: String) {
        // Create a simple spark/circle texture programmatically
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 4, dy: 4))
        }
        self.init(image: image)
    }
}
