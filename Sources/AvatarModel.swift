import UIKit

enum AvatarGender: String, Codable {
    case male
    case female
}

/// Persisted avatar state. Only gender is used; other customization has been removed.
/// Old data is migrated: decode tolerantly and fall back to .male on any failure.
struct AvatarPersistence: Codable {
    var gender: AvatarGender
    init(gender: AvatarGender = .male) {
        self.gender = gender
    }
}

/// Legacy config type kept for backward compatibility. Only `gender` is used.
/// Decoding is migration-safe: old UserDefaults data decodes without crashing; unknown keys are ignored.
struct AvatarConfig: Codable, Equatable {
    var gender: AvatarGender
    var baseStyleIndex: Int
    var hairStyleIndex: Int
    var accessoryIndex: Int
    var skinColorHex: String
    var hairColorHex: String
    var accentColorHex: String

    static let `default` = AvatarConfig(
        gender: .male,
        baseStyleIndex: 0,
        hairStyleIndex: 0,
        accessoryIndex: 0,
        skinColorHex: "#E0B090",
        hairColorHex: "#2E2A28",
        accentColorHex: "#FFD27A"
    )

    init(gender: AvatarGender, baseStyleIndex: Int = 0, hairStyleIndex: Int = 0, accessoryIndex: Int = 0, skinColorHex: String = "#E0B090", hairColorHex: String = "#2E2A28", accentColorHex: String = "#FFD27A") {
        self.gender = gender
        self.baseStyleIndex = baseStyleIndex
        self.hairStyleIndex = hairStyleIndex
        self.accessoryIndex = accessoryIndex
        self.skinColorHex = skinColorHex
        self.hairColorHex = hairColorHex
        self.accentColorHex = accentColorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gender = (try? c.decode(AvatarGender.self, forKey: .gender)) ?? .male
        baseStyleIndex = (try? c.decode(Int.self, forKey: .baseStyleIndex)) ?? 0
        hairStyleIndex = (try? c.decode(Int.self, forKey: .hairStyleIndex)) ?? 0
        accessoryIndex = (try? c.decode(Int.self, forKey: .accessoryIndex)) ?? 0
        skinColorHex = (try? c.decode(String.self, forKey: .skinColorHex)) ?? Self.default.skinColorHex
        hairColorHex = (try? c.decode(String.self, forKey: .hairColorHex)) ?? Self.default.hairColorHex
        accentColorHex = (try? c.decode(String.self, forKey: .accentColorHex)) ?? Self.default.accentColorHex
    }
}
