import SpriteKit
import UIKit

extension Notification.Name {
    static let avatarDidChange = Notification.Name("avatarDidChange")
}

final class AvatarStore {
    static let shared = AvatarStore()

    private let genderKey = "avatar.gender"
    private let configKey = "avatar.config.v1"
    private let fileName = "avatar.png"
    private var cachedImage: UIImage?
    private var cachedTexture: SKTexture?
    private var cachedGender: AvatarGender?
    private static var hasLoggedMissingAsset = false

    /// Persisted gender. Uses key "avatar.gender". Defaults to .male if missing/invalid. Migrates from old config once.
    var gender: AvatarGender {
        get {
            if let raw = UserDefaults.standard.string(forKey: genderKey), let g = AvatarGender(rawValue: raw) {
                return g
            }
            migrateFromLegacyIfNeeded()
            return UserDefaults.standard.string(forKey: genderKey).flatMap { AvatarGender(rawValue: $0) } ?? .male
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: genderKey)
            cachedGender = newValue
            let image = imageForGender(newValue)
            cachedImage = image
            cachedTexture = SKTexture(image: image)
            saveImage(image)
            NotificationCenter.default.post(name: .avatarDidChange, object: self)
        }
    }

    func setGender(_ gender: AvatarGender) {
        self.gender = gender
    }

    private func migrateFromLegacyIfNeeded() {
        if UserDefaults.standard.string(forKey: genderKey) != nil { return }
        let legacy = loadConfig()
        UserDefaults.standard.set(legacy.gender.rawValue, forKey: genderKey)
    }

    /// Persist and display: saves gender, updates cache, and posts avatarDidChange. Kept for backward compatibility.
    func save(_ config: AvatarConfig) {
        gender = config.gender
    }

    /// Loads persisted config; migration-safe. Prefers avatar.gender, then legacy config decode.
    func loadConfig() -> AvatarConfig {
        let g = UserDefaults.standard.string(forKey: genderKey).flatMap { AvatarGender(rawValue: $0) }
        if let g { return AvatarConfig(gender: g) }
        guard let data = UserDefaults.standard.data(forKey: configKey) else {
            return .default
        }
        if let p = try? JSONDecoder().decode(AvatarPersistence.self, from: data) {
            return AvatarConfig(gender: p.gender)
        }
        if let c = try? JSONDecoder().decode(AvatarConfig.self, from: data) {
            return c
        }
        return .default
    }

    func currentAvatarImage() -> UIImage {
        let g = gender
        if cachedGender == g, let cachedImage {
            return cachedImage
        }
        cachedGender = g
        let image = imageForGender(g)
        cachedImage = image
        cachedTexture = SKTexture(image: image)
        saveImage(image)
        return image
    }

    func currentAvatarTexture() -> SKTexture {
        let g = gender
        if cachedGender == g, let cachedTexture {
            return cachedTexture
        }
        cachedGender = g
        let image = imageForGender(g)
        cachedImage = image
        let texture = SKTexture(image: image)
        cachedTexture = texture
        saveImage(image)
        return texture
    }

    func renderAvatarTexture(config: AvatarConfig) -> SKTexture {
        SKTexture(image: imageForGender(config.gender))
    }

    func currentAvatarTexture(completion: @escaping (SKTexture) -> Void) {
        if let cachedTexture {
            completion(cachedTexture)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = self?.currentAvatarImage() ?? self?.placeholderImage() ?? UIImage()
            let texture = SKTexture(image: image)
            DispatchQueue.main.async {
                self?.cachedTexture = texture
                completion(texture)
            }
        }
    }

    func renderAvatarImage(config: AvatarConfig, size: CGSize = CGSize(width: 256, height: 256)) -> UIImage {
        imageForGender(config.gender)
    }

    private func imageForGender(_ gender: AvatarGender) -> UIImage {
        let name = gender == .female ? "avatar_female" : "avatar_male"
        if let image = UIImage(named: name) {
            return image
        }
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        if let resourcesBundle = Bundle.main.url(forResource: "Resources", withExtension: "bundle") {
            let bundlePath = resourcesBundle.appendingPathComponent("\(name).png")
            if FileManager.default.fileExists(atPath: bundlePath.path),
               let image = UIImage(contentsOfFile: bundlePath.path) {
                return image
            }
        }
        if !Self.hasLoggedMissingAsset {
            Self.hasLoggedMissingAsset = true
            debugPrint("AvatarStore: missing asset '\(name)', using placeholder")
        }
        return placeholderImage()
    }

    private func placeholderImage() -> UIImage {
        if let fallback = UIImage(named: "DefaultAvatar") {
            return fallback
        }
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor(white: 0.2, alpha: 1.0).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func saveImage(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        let url = avatarURL()
        try? data.write(to: url, options: [.atomic])
    }

    private func avatarURL() -> URL {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docDir.appendingPathComponent(fileName)
    }
}
