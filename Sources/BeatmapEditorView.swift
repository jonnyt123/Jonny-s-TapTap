import SwiftUI
import SpriteKit
import UniformTypeIdentifiers
import UIKit

// MARK: - Editor Mode

private enum EditorMode {
    case setup
    case editing
}

// MARK: - Beatmap Editor View

struct BeatmapEditorView: View {
    @Environment(\.dismiss) private var dismiss
    /// When non-nil, called after a successful save with the new beatmap ID (e.g. "user_beatmap"). Parent should dismiss editor, show setlist, and preselect this song.
    var onBeatmapSaved: ((String) -> Void)? = nil
    @State private var editorMode: EditorMode = .setup
    @State private var showPicker = false
    @State private var audioURL: URL?
    @State private var bpm: Int = 120
    @State private var lanes = 4
    @State private var offsetMs: Int64 = 0
    @State private var createdAt = Date()
    @State private var statusText = "Pick an MP3 to start."
    @State private var engine = EditorAudioEngine()
    @StateObject private var recorder = BeatmapRecorder(lanes: 4)
    @State private var scene = BeatmapEditorScene()
    @State private var showInstructions = true
    @State private var setupErrorMessage: String?

    private var canStartEditing: Bool {
        guard audioURL != nil else { return false }
        guard bpm > 0 else { return false }
        guard lanes == 3 || lanes == 4 else { return false }
        return true
    }

    var body: some View {
        ZStack {
            editorBackground

            if editorMode == .setup {
                setupView
                    .transition(.opacity)
            } else {
                editingView
                    .transition(.opacity)
            }

            if showInstructions {
                instructionsOverlay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: editorMode)
        .onAppear {
            if editorMode == .editing {
                configureScene()
            }
        }
        .sheet(isPresented: $showPicker) {
            MP3Picker { pickedURL in
                Task { await handlePicked(url: pickedURL) }
            }
        }
        .onChange(of: lanes) { _, newValue in
            let clamped = min(4, max(3, newValue))
            if clamped != newValue { lanes = clamped; return }
            recorder.setLanes(lanes)
            scene.lanes = lanes
            if editorMode == .editing { Task { await autosave() } }
        }
        .onChange(of: recorder.notes) { _, _ in
            if editorMode == .editing { Task { await autosave() } }
        }
        .onChange(of: offsetMs) { _, _ in
            if editorMode == .editing { Task { await autosave() } }
        }
        .onDisappear {
            Task { await engine.stop() }
        }
    }

    private var editorBackground: some View {
        Color(red: 0.08, green: 0.06, blue: 0.12)
            .ignoresSafeArea()
    }

    // MARK: - Setup Mode

    private var setupView: some View {
        ScrollView {
            VStack(spacing: RTTheme.Spacing.block) {
                headerBar(showCloseOnly: true)

                Text("New Beatmap")
                    .font(RTTheme.Fonts.title(22))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .padding(.top, RTTheme.Spacing.screen)

                VStack(spacing: RTTheme.Spacing.lg) {
                    RTSecondaryButton(title: "Select Audio", icon: "music.note") {
                        RTHaptics.impact()
                        showPicker = true
                    }
                    .frame(minHeight: 44)

                    if let url = audioURL {
                        Text(url.lastPathComponent)
                            .font(RTTheme.Fonts.caption(12))
                            .foregroundStyle(RTTheme.Colors.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    bpmSection
                    lanesSection

                    if let msg = setupErrorMessage {
                        Text(msg)
                            .font(RTTheme.Fonts.caption(12))
                            .foregroundStyle(RTTheme.Colors.selectedRedBright)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: startEditing) {
                        HStack(spacing: RTTheme.Spacing.medium) {
                            Image(systemName: "pencil.and.outline")
                                .font(RTTheme.Fonts.body(18))
                            Text("Start Editing")
                                .font(RTTheme.Fonts.body(16))
                        }
                        .foregroundStyle(RTTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, RTTheme.Spacing.medium)
                        .background(
                            LinearGradient(
                                colors: canStartEditing
                                    ? [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd]
                                    : [Color(white: 0.2), Color(white: 0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(RTTheme.Radius.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                                .stroke(canStartEditing ? RTTheme.Colors.primaryStroke.opacity(0.9) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .disabled(!canStartEditing)
                    .opacity(canStartEditing ? 1 : 0.8)
                }
                .padding(.horizontal, RTTheme.Spacing.screen)
                .padding(.top, RTTheme.Spacing.lg)

                Spacer(minLength: 40)
            }
        }
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
    }

    private var bpmSection: some View {
        VStack(alignment: .leading, spacing: RTTheme.Spacing.sm) {
            Text("Set BPM")
                .font(RTTheme.Fonts.callout(14))
                .foregroundStyle(RTTheme.Colors.textSecondary)
            HStack(spacing: RTTheme.Spacing.md) {
                Button(action: { if bpm > 1 { bpm -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(RTTheme.Colors.textPrimary)
                }
                Text("\(bpm)")
                    .font(RTTheme.Fonts.title(24))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .frame(minWidth: 60)
                Button(action: { if bpm < 999 { bpm += 1 } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(RTTheme.Colors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RTTheme.Spacing.sm)
        }
    }

    private var lanesSection: some View {
        VStack(alignment: .leading, spacing: RTTheme.Spacing.sm) {
            Text("Choose Lanes")
                .font(RTTheme.Fonts.callout(14))
                .foregroundStyle(RTTheme.Colors.textSecondary)
            HStack(spacing: RTTheme.Spacing.md) {
                laneButton(laneCount: 3)
                laneButton(laneCount: 4)
            }
        }
    }

    private func laneButton(laneCount: Int) -> some View {
        let isSelected = lanes == laneCount
        return Button(action: {
            RTHaptics.impact()
            lanes = laneCount
        }) {
            Text("\(laneCount) LANES")
                .font(RTTheme.Fonts.headline(14))
                .foregroundStyle(isSelected ? RTTheme.Colors.textPrimary : RTTheme.Colors.textMuted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, RTTheme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                        .fill(isSelected ? RTTheme.Colors.primaryStroke.opacity(0.4) : RTTheme.Colors.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                        .stroke(isSelected ? RTTheme.Colors.primaryStroke : RTTheme.Colors.surfaceStroke, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func startEditing() {
        setupErrorMessage = nil
        guard let _ = audioURL else {
            setupErrorMessage = "Select audio first."
            return
        }
        guard bpm > 0 else {
            setupErrorMessage = "Set BPM to a value greater than 0."
            return
        }
        if lanes != 3 && lanes != 4 {
            lanes = 4
        }
        recorder.setLanes(lanes)
        scene.lanes = lanes
        configureScene()
        withAnimation(.easeInOut(duration: 0.25)) {
            editorMode = .editing
        }
    }

    // MARK: - Editing Mode

    private var editingView: some View {
        VStack(spacing: 16) {
            headerBar(showCloseOnly: false)
            SpriteView(scene: scene)
                .frame(maxWidth: .infinity, maxHeight: 260)
                .background(Color.black.opacity(0.9))
                .cornerRadius(12)
                .focusable(false)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            controls
            infoPanel
            Spacer()
        }
        .padding()
        .background(Color(white: 0.95))
    }

    private func headerBar(showCloseOnly: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Beat Map Editor")
                    .font(editorFont(20))
                    .foregroundStyle(editorMode == .setup ? RTTheme.Colors.textPrimary : Color.black)
                if editorMode == .editing {
                    Text(statusText)
                        .font(editorFont(12))
                        .foregroundColor(.black)
                }
            }
            Spacer()
            if !showCloseOnly {
                Button("Help") { showInstructions = true }
                    .font(editorFont(12))
                    .padding(.trailing, 6)
                    .foregroundStyle(.black)
            }
            Button("Close") { dismiss() }
                .font(editorFont(12))
                .foregroundStyle(editorMode == .setup ? RTTheme.Colors.textPrimary : .black)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                editorActionButton(title: "Pick MP3", icon: "music.note") { showPicker = true }
                editorActionButton(title: "Play", icon: "play.fill") { Task { try? await engine.play() } }
                editorActionButton(title: "Pause", icon: "pause.fill") { Task { await engine.pause() } }
                editorActionButton(title: "Restart", icon: "backward.fill") { Task { try? await engine.playFromStart() } }
            }

            HStack(spacing: 12) {
                Text("Change Lane")
                    .font(editorFont(11))
                    .foregroundColor(.black)
                Picker("", selection: $lanes) {
                    Text("3").tag(3)
                    Text("4").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .font(editorFont(11))
                Stepper("Offset \(offsetMs)ms", value: $offsetMs, in: -500...500, step: 5)
                    .font(editorFont(11))
            }

            HStack(spacing: 12) {
                editorActionButton(title: "Add Note", icon: "plus.circle") { showInstructions = true }
                editorActionButton(title: "Remove Note", icon: "minus.circle") { recorder.undo() }
                editorActionButton(title: "Save Beatmap", icon: "square.and.arrow.down") { Task { await autosave(force: true) } }
                editorActionButton(title: "Back", icon: "chevron.left") { dismiss() }
            }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 4)
    }

    private func editorActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(editorFont(12))
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes: \(recorder.notes.count)")
                .font(editorFont(12))
            if let audioURL {
                Text("Song: \(audioURL.lastPathComponent)")
                    .font(editorFont(11))
                    .foregroundColor(.black)
            }
        }
        .foregroundColor(.black)
    }

    private var instructionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("How to Use the Beatmap Editor")
                        .font(editorFont(16))
                    Spacer()
                    Button(action: { showInstructions = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(editorFont(18))
                    }
                }
                .foregroundColor(.black)

                Text("1. Tap “Pick MP3” to import a song.")
                Text("2. Choose 3 or 4 lanes.")
                Text("3. Press Play, then tap lanes to add notes.")
                Text("4. Use Undo if you make a mistake.")
                Text("5. Beatmaps auto-save to Documents.")
            }
            .font(editorFont(12))
            .foregroundColor(.black)
            .padding(16)
            .frame(maxWidth: 300)
            .background(Color(red: 0.92, green: 0.92, blue: 0.94))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func editorFont(_ size: CGFloat) -> Font {
        if UIFont(name: "JonnysTapTap", size: size) != nil {
            return .custom("JonnysTapTap", size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }

    private func configureScene() {
        scene.scaleMode = .resizeFill
        scene.lanes = lanes
        scene.recorder = recorder
        scene.editorAudioEngine = engine
    }

    @MainActor
    private func handlePicked(url: URL) async {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let copied = try SongImport.copyIntoDocuments(from: url)
            audioURL = copied
            createdAt = Date()
            offsetMs = 0
            lanes = min(4, max(3, lanes))
            recorder.setLanes(lanes)
            scene.lanes = lanes
            try await engine.load(url: copied)
            statusText = "Loaded \(copied.lastPathComponent)"
            await autosave(force: true)
        } catch {
            statusText = "Failed to import: \(error.localizedDescription)"
        }
    }

    private func autosave(force: Bool = false) async {
        guard let audioURL else { return }
        let safeLanes = lanes == 3 || lanes == 4 ? lanes : 4
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)_user_\(safeLanes)lane.json"
        let saveURL = BeatmapStore.documentsURL(filename: fileName)
        let durationSec = await engine.durationSec
        let beatmap = Beatmap(
            version: 1,
            createdAt: createdAt,
            lanes: safeLanes,
            offsetMs: offsetMs,
            song: BeatmapSong(
                filename: audioURL.lastPathComponent,
                durationSec: durationSec,
                sha256: nil
            ),
            notes: recorder.sortedNotes()
        )
        if force || !recorder.notes.isEmpty {
            try? BeatmapStore.save(beatmap, to: saveURL)
            if let callback = onBeatmapSaved {
                DispatchQueue.main.async { callback("user_beatmap") }
            }
        }
    }
}

// MARK: - MP3 Picker

struct MP3Picker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.mp3, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
