import SwiftUI
import AudioToolbox
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject var gameState: GameState

    @State private var showCalibration = false
    @State private var showResetConfirm = false
    @State private var showClearScores = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                audioSection
                gameplaySection
                visualsSection
                controlsSection
                accessibilitySection
                progressSection
                gameCenterSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationSheetView()
        }
        .sheet(isPresented: $showClearScores) {
            ClearHighScoresView(gameState: gameState)
        }
        .confirmationDialog("Reset local progress?", isPresented: $showResetConfirm) {
            Button("Reset Progress", role: .destructive) {
                gameState.resetLocalProgress()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears XP, level, coins, unlocks, and local high scores.")
        }
    }

    private var audioSection: some View {
        Section(header: Text("Audio & Sync")) {
            SliderRow(title: "Music Volume", value: $settings.musicVolume, range: 0...1, format: "%.0f%%", multiplier: 100)
            SliderRow(title: "SFX Volume", value: $settings.sfxVolume, range: 0...1, format: "%.0f%%", multiplier: 100)
            Toggle("Hit Sound", isOn: $settings.hitSoundEnabled)
            IntSliderRow(title: "Audio Offset (ms)", value: $settings.audioOffsetMs, range: -300...300, step: 5)
            Button("Tap-to-Calibrate") { showCalibration = true }
            Toggle("Low Latency Mode", isOn: $settings.lowLatencyMode)
        }
    }

    private var accountSection: some View {
        Section {
            AccountStatusView()
                .listRowInsets(EdgeInsets())
        }
    }

    private var gameplaySection: some View {
        Section(header: Text("Gameplay")) {
            SliderRow(title: "Note Speed", value: $settings.noteSpeedMultiplier, range: 0.6...1.6, format: "%.2fx", multiplier: 1)
            Picker("Hit Window", selection: $settings.hitWindowPreset) {
                ForEach(HitWindowPreset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Fail Mode", isOn: $settings.failModeEnabled)
            Toggle("Revenge Mode", isOn: $settings.revengeModeEnabled)
        }
    }

    private var visualsSection: some View {
        Section(header: Text("Visuals")) {
            Picker("Background Intensity", selection: $settings.backgroundIntensity) {
                ForEach(BackgroundIntensity.allCases, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            Toggle("Disable Background Animations", isOn: $settings.disableBackgroundAnimations)
            Toggle("Note Glow / Trails", isOn: $settings.noteGlowEnabled)
            Picker("FPS Cap", selection: $settings.fpsCap) {
                ForEach(FPSCap.allCases, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
        }
    }

    private var controlsSection: some View {
        Section(header: Text("Controls")) {
            SliderRow(title: "Button Size", value: $settings.buttonSizeScale, range: 0.7...1.4, format: "%.0f%%", multiplier: 100)
            Toggle("Left-Hand Mode", isOn: $settings.leftHandedMode)
            Toggle("Haptics", isOn: $settings.hapticsEnabled)
        }
    }

    private var accessibilitySection: some View {
        Section(header: Text("Accessibility")) {
            Picker("Colorblind Preset", selection: $settings.colorblindPreset) {
                ForEach(ColorblindPreset.allCases, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            Toggle("High Contrast Notes", isOn: $settings.highContrastNotes)
            Toggle("Reduce Flashing", isOn: $settings.reduceFlashing)
            Toggle("Screen Shake", isOn: $settings.screenShakeEnabled)
        }
    }

    private var progressSection: some View {
        Section(header: Text("Progress & Data")) {
            Toggle("Cloud Sync", isOn: $settings.cloudSyncEnabled)
            Button("Reset Local Progress", role: .destructive) { showResetConfirm = true }
            Button("Clear High Scores") { showClearScores = true }
        }
    }

    private var gameCenterSection: some View {
        Section(header: Text("Game Center")) {
            GameCenterDebugView()
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    let multiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value * multiplier))
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

private struct IntSliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
                    .foregroundColor(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
        }
    }
}

private struct CalibrationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    @State private var startTime: TimeInterval?
    @State private var tapCount = 0
    @State private var pulse = false

    private let bpm: Double = 120
    private var beatInterval: Double { 60.0 / bpm }
    private var beatTimer: Timer.TimerPublisher {
        Timer.publish(every: beatInterval, on: .main, in: .common)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Tap Calibration")
                .font(.system(size: 22, weight: .bold))

            Text("Tap on each beat. We’ll average your timing to set audio offset.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            ZStack {
                Circle()
                    .fill(Color.red.opacity(pulse ? 0.9 : 0.35))
                    .frame(width: pulse ? 140 : 110, height: pulse ? 140 : 110)
                    .animation(.easeInOut(duration: 0.15), value: pulse)
                Text(settings.calibrationActive ? "TAP" : "START")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white)
            }
            .onTapGesture { handleTap() }
            .onReceive(beatTimer.autoconnect()) { _ in
                guard settings.calibrationActive else { return }
                pulse.toggle()
                AudioServicesPlaySystemSound(1104)
            }

            Text("Samples: \(tapCount) / 12")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Start") { startCalibration() }
                    .buttonStyle(.borderedProminent)
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .onDisappear {
            settings.cancelCalibration()
        }
    }

    private func startCalibration() {
        tapCount = 0
        startTime = CACurrentMediaTime()
        settings.startCalibration()
    }

    private func handleTap() {
        if !settings.calibrationActive {
            startCalibration()
            return
        }
        guard let start = startTime else { return }
        let now = CACurrentMediaTime()
        let beatNumber = round((now - start) / beatInterval)
        let beatTime = start + beatNumber * beatInterval
        let deltaMs = Int(((now - beatTime) * 1000.0).rounded())
        settings.recordCalibrationSample(deltaMs: deltaMs)
        tapCount += 1
        if !settings.calibrationActive {
            dismiss()
        }
    }
}

private struct ClearHighScoresView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameState: GameState
    @State private var selectedSongID = SongMetadata.library.first?.id ?? SongMetadata.default.id
    @State private var selectedDifficulty: Difficulty = .medium

    var body: some View {
        NavigationStack {
            Form {
                Picker("Song", selection: $selectedSongID) {
                    ForEach(SongMetadata.library) { song in
                        Text(song.title).tag(song.id)
                    }
                }
                Picker("Difficulty", selection: $selectedDifficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
            }
            .navigationTitle("Clear High Scores")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        gameState.clearPersonalBest(songID: selectedSongID, difficulty: selectedDifficulty)
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

private extension HitWindowPreset {
    var title: String {
        switch self {
        case .lenient: return "Lenient"
        case .standard: return "Standard"
        case .strict: return "Strict"
        }
    }
}

private extension BackgroundIntensity {
    var title: String {
        switch self {
        case .full: return "Full"
        case .dim: return "Dim"
        case .static: return "Static"
        }
    }
}

private extension FPSCap {
    var title: String {
        switch self {
        case .auto: return "Auto"
        case .fps60: return "60"
        case .fps120: return "120"
        case .unlimited: return "Unlimited"
        }
    }
}

private extension ColorblindPreset {
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .deuteranopia: return "Deuteranopia"
        case .protanopia: return "Protanopia"
        case .tritanopia: return "Tritanopia"
        }
    }
}

private extension Difficulty {
    var title: String { rawValue }
}
