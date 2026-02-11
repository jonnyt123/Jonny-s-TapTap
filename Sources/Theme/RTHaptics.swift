import UIKit

/// Lightweight haptics for UI actions. Respects SettingsManager.hapticsEnabled.
enum RTHaptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)

    /// Call once at app launch or before first use to reduce first-tap latency.
    static func prepare() {
        light.prepare()
    }

    /// Trigger light impact for button taps / selections. No-op if haptics disabled.
    @MainActor
    static func impact() {
        guard SettingsManager.shared.hapticsEnabled else { return }
        light.impactOccurred()
        light.prepare()
    }

    /// Trigger for success-style actions (e.g. purchase, unlock).
    @MainActor
    static func success() {
        guard SettingsManager.shared.hapticsEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}
