import Foundation
import Combine

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Audio & Sync
    @Published var musicVolume: Double {
        didSet {
            if isAdjustingMusicVolume { return }
            let clamped = clamp(musicVolume, 0, 1)
            if musicVolume != clamped {
                isAdjustingMusicVolume = true
                musicVolume = clamped
                isAdjustingMusicVolume = false
                return
            }
            store(musicVolume, key: Keys.musicVolume)
            bump()
        }
    }
    @Published var sfxVolume: Double {
        didSet {
            if isAdjustingSfxVolume { return }
            let clamped = clamp(sfxVolume, 0, 1)
            if sfxVolume != clamped {
                isAdjustingSfxVolume = true
                sfxVolume = clamped
                isAdjustingSfxVolume = false
                return
            }
            store(sfxVolume, key: Keys.sfxVolume)
            bump()
        }
    }
    @Published var hitSoundEnabled: Bool { didSet { store(hitSoundEnabled, key: Keys.hitSoundEnabled); bump() } }
    @Published var audioOffsetMs: Int {
        didSet {
            if isAdjustingAudioOffset { return }
            let clamped = clamp(audioOffsetMs, -300, 300)
            if audioOffsetMs != clamped {
                isAdjustingAudioOffset = true
                audioOffsetMs = clamped
                isAdjustingAudioOffset = false
                return
            }
            store(audioOffsetMs, key: Keys.audioOffsetMs)
            bump()
        }
    }
    @Published var lowLatencyMode: Bool { didSet { store(lowLatencyMode, key: Keys.lowLatencyMode); bump() } }

    // MARK: - Gameplay
    @Published var noteSpeedMultiplier: Double {
        didSet {
            if isAdjustingNoteSpeed { return }
            let clamped = clamp(noteSpeedMultiplier, 0.6, 1.6)
            if noteSpeedMultiplier != clamped {
                isAdjustingNoteSpeed = true
                noteSpeedMultiplier = clamped
                isAdjustingNoteSpeed = false
                return
            }
            store(noteSpeedMultiplier, key: Keys.noteSpeedMultiplier)
            bump()
        }
    }
    @Published var hitWindowPreset: HitWindowPreset { didSet { store(hitWindowPreset.rawValue, key: Keys.hitWindowPreset); bump() } }
    @Published var failModeEnabled: Bool { didSet { store(failModeEnabled, key: Keys.failModeEnabled); bump() } }
    @Published var revengeModeEnabled: Bool { didSet { store(revengeModeEnabled, key: Keys.revengeModeEnabled); bump() } }

    // MARK: - Visuals
    @Published var backgroundIntensity: BackgroundIntensity { didSet { store(backgroundIntensity.rawValue, key: Keys.backgroundIntensity); bump() } }
    @Published var disableBackgroundAnimations: Bool { didSet { store(disableBackgroundAnimations, key: Keys.disableBackgroundAnimations); bump() } }
    @Published var noteGlowEnabled: Bool { didSet { store(noteGlowEnabled, key: Keys.noteGlowEnabled); bump() } }
    @Published var fpsCap: FPSCap { didSet { store(fpsCap.rawValue, key: Keys.fpsCap); bump() } }

    // MARK: - Controls
    @Published var buttonSizeScale: Double {
        didSet {
            if isAdjustingButtonSize { return }
            let clamped = clamp(buttonSizeScale, 0.7, 1.4)
            if buttonSizeScale != clamped {
                isAdjustingButtonSize = true
                buttonSizeScale = clamped
                isAdjustingButtonSize = false
                return
            }
            store(buttonSizeScale, key: Keys.buttonSizeScale)
            bump()
        }
    }
    @Published var leftHandedMode: Bool { didSet { store(leftHandedMode, key: Keys.leftHandedMode); bump() } }
    @Published var hapticsEnabled: Bool { didSet { store(hapticsEnabled, key: Keys.hapticsEnabled); bump() } }

    // MARK: - Accessibility
    @Published var colorblindPreset: ColorblindPreset { didSet { store(colorblindPreset.rawValue, key: Keys.colorblindPreset); bump() } }
    @Published var highContrastNotes: Bool { didSet { store(highContrastNotes, key: Keys.highContrastNotes); bump() } }
    @Published var reduceFlashing: Bool { didSet { store(reduceFlashing, key: Keys.reduceFlashing); bump() } }
    @Published var screenShakeEnabled: Bool { didSet { store(screenShakeEnabled, key: Keys.screenShakeEnabled); bump() } }

    // MARK: - Cloud Sync
    @Published var cloudSyncEnabled: Bool { didSet { store(cloudSyncEnabled, key: Keys.cloudSyncEnabled); bump() } }

    @Published private(set) var settingsRevision: Int = 0

    // Calibration
    @Published private(set) var calibrationActive: Bool = false
    private var calibrationSamples: [Int] = []
    private let calibrationTargetCount = 12
    private var isAdjustingMusicVolume = false
    private var isAdjustingSfxVolume = false
    private var isAdjustingAudioOffset = false
    private var isAdjustingNoteSpeed = false
    private var isAdjustingButtonSize = false

    private init() {
        let defaults = UserDefaults.standard
        musicVolume = defaults.object(forKey: Keys.musicVolume) as? Double ?? 0.8
        sfxVolume = defaults.object(forKey: Keys.sfxVolume) as? Double ?? 0.8
        hitSoundEnabled = defaults.object(forKey: Keys.hitSoundEnabled) as? Bool ?? true
        audioOffsetMs = defaults.object(forKey: Keys.audioOffsetMs) as? Int ?? 0
        lowLatencyMode = defaults.object(forKey: Keys.lowLatencyMode) as? Bool ?? false

        noteSpeedMultiplier = defaults.object(forKey: Keys.noteSpeedMultiplier) as? Double ?? 1.0
        hitWindowPreset = HitWindowPreset(rawValue: defaults.string(forKey: Keys.hitWindowPreset) ?? "standard") ?? .standard
        failModeEnabled = defaults.object(forKey: Keys.failModeEnabled) as? Bool ?? true
        revengeModeEnabled = defaults.object(forKey: Keys.revengeModeEnabled) as? Bool ?? false

        backgroundIntensity = BackgroundIntensity(rawValue: defaults.string(forKey: Keys.backgroundIntensity) ?? "full") ?? .full
        disableBackgroundAnimations = defaults.object(forKey: Keys.disableBackgroundAnimations) as? Bool ?? false
        noteGlowEnabled = defaults.object(forKey: Keys.noteGlowEnabled) as? Bool ?? true
        fpsCap = FPSCap(rawValue: defaults.string(forKey: Keys.fpsCap) ?? "auto") ?? .auto

        buttonSizeScale = defaults.object(forKey: Keys.buttonSizeScale) as? Double ?? 1.0
        leftHandedMode = defaults.object(forKey: Keys.leftHandedMode) as? Bool ?? false
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true

        colorblindPreset = ColorblindPreset(rawValue: defaults.string(forKey: Keys.colorblindPreset) ?? "normal") ?? .normal
        highContrastNotes = defaults.object(forKey: Keys.highContrastNotes) as? Bool ?? false
        reduceFlashing = defaults.object(forKey: Keys.reduceFlashing) as? Bool ?? false
        screenShakeEnabled = defaults.object(forKey: Keys.screenShakeEnabled) as? Bool ?? true

        cloudSyncEnabled = defaults.object(forKey: Keys.cloudSyncEnabled) as? Bool ?? true
    }

    func startCalibration() {
        calibrationSamples.removeAll()
        calibrationActive = true
    }

    func recordCalibrationSample(deltaMs: Int) {
        guard calibrationActive else { return }
        calibrationSamples.append(deltaMs)
        if calibrationSamples.count >= calibrationTargetCount {
            let avg = calibrationSamples.reduce(0, +) / calibrationSamples.count
            audioOffsetMs = clamp(-avg, -300, 300)
            calibrationActive = false
            calibrationSamples.removeAll()
        }
    }

    func cancelCalibration() {
        calibrationActive = false
        calibrationSamples.removeAll()
    }

    private func bump() {
        settingsRevision += 1
    }

    private func store<T>(_ value: T, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    private func clamp(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        min(max(value, minValue), maxValue)
    }

    private enum Keys {
        static let musicVolume = "settings.musicVolume"
        static let sfxVolume = "settings.sfxVolume"
        static let hitSoundEnabled = "settings.hitSoundEnabled"
        static let audioOffsetMs = "settings.audioOffsetMs"
        static let lowLatencyMode = "settings.lowLatencyMode"

        static let noteSpeedMultiplier = "settings.noteSpeedMultiplier"
        static let hitWindowPreset = "settings.hitWindowPreset"
        static let failModeEnabled = "settings.failModeEnabled"
        static let revengeModeEnabled = "settings.revengeModeEnabled"

        static let backgroundIntensity = "settings.backgroundIntensity"
        static let disableBackgroundAnimations = "settings.disableBackgroundAnimations"
        static let noteGlowEnabled = "settings.noteGlowEnabled"
        static let fpsCap = "settings.fpsCap"

        static let buttonSizeScale = "settings.buttonSizeScale"
        static let leftHandedMode = "settings.leftHandedMode"
        static let hapticsEnabled = "settings.hapticsEnabled"

        static let colorblindPreset = "settings.colorblindPreset"
        static let highContrastNotes = "settings.highContrastNotes"
        static let reduceFlashing = "settings.reduceFlashing"
        static let screenShakeEnabled = "settings.screenShakeEnabled"

        static let cloudSyncEnabled = "settings.cloudSyncEnabled"
    }
}

enum HitWindowPreset: String, CaseIterable {
    case lenient
    case standard
    case strict

    var perfectMs: Double {
        switch self {
        case .lenient: return 70
        case .standard: return 50
        case .strict: return 35
        }
    }

    var greatMs: Double {
        switch self {
        case .lenient: return 110
        case .standard: return 80
        case .strict: return 60
        }
    }

    var goodMs: Double {
        switch self {
        case .lenient: return 180
        case .standard: return 160
        case .strict: return 120
        }
    }
}

enum BackgroundIntensity: String, CaseIterable {
    case full
    case dim
    case `static`
}

enum FPSCap: String, CaseIterable {
    case auto
    case fps60
    case fps120
    case unlimited
}

enum ColorblindPreset: String, CaseIterable {
    case normal
    case deuteranopia
    case protanopia
    case tritanopia
}

// Verification checklist:
// - Audio: adjust music/SFX sliders, hit sound toggle, and low latency during play.
// - Timing: change hit window preset and audio offset, confirm judgement shifts.
// - Gameplay: toggle fail mode, note speed, and left-hand mode.
// - Visuals: background intensity/animations, note glow, FPS cap, reduce flashing.
// - Controls: button size + haptics feedback on hits.
// - Accessibility: colorblind palettes and high-contrast notes.
// - Progress: reset progress, clear highscores, cloud sync on/off.


