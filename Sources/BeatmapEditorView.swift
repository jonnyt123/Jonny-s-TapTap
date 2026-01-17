import SwiftUI
import SpriteKit
import UniformTypeIdentifiers

struct BeatmapEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var audioURL: URL?
    @State private var lanes = 4
    @State private var offsetMs: Int64 = 0
    @State private var createdAt = Date()
    @State private var statusText = "Pick an MP3 to start."
    @State private var engine = EditorAudioEngine()
    @StateObject private var recorder = BeatmapRecorder(lanes: 4)
    @State private var scene = BeatmapEditorScene()
    @State private var showInstructions = true

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header
                SpriteView(scene: scene)
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                controls
                infoPanel
                Spacer()
            }
            if showInstructions {
                instructionsOverlay
            }
        }
        .padding()
        .onAppear {
            configureScene()
        }
        .sheet(isPresented: $showPicker) {
            MP3Picker { pickedURL in
                handlePicked(url: pickedURL)
            }
        }
        .onChange(of: lanes) { _, newValue in
            recorder.setLanes(newValue)
            scene.lanes = newValue
            autosave()
        }
        .onChange(of: recorder.notes) { _, _ in
            autosave()
        }
        .onChange(of: offsetMs) { _, _ in
            autosave()
        }
        .onDisappear {
            engine.stop()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BEATMAP EDITOR")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button("Help") { showInstructions = true }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.trailing, 6)
            Button("Close") { dismiss() }
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("Pick MP3") { showPicker = true }
                Button("Play") { try? engine.play() }
                Button("Pause") { engine.pause() }
                Button("Restart") { try? engine.playFromStart() }
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
                Picker("Lanes", selection: $lanes) {
                    Text("3").tag(3)
                    Text("4").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)

                Stepper("Offset \(offsetMs)ms", value: $offsetMs, in: -500...500, step: 5)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }

            HStack(spacing: 10) {
                Button("Undo") { recorder.undo() }
                Button("Save Now") { autosave(force: true) }
            }
            .buttonStyle(.bordered)
        }
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes: \(recorder.notes.count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
            if let audioURL {
                Text("Song: \(audioURL.lastPathComponent)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .foregroundColor(.white)
    }

    private var instructionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("How to Use the Beatmap Editor")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: { showInstructions = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.white)

                Text("1. Tap “Pick MP3” to import a song.")
                Text("2. Choose 3 or 4 lanes.")
                Text("3. Press Play, then tap lanes to add notes.")
                Text("4. Use Undo if you make a mistake.")
                Text("5. Beatmaps auto-save to Documents.")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .padding(16)
            .frame(maxWidth: 300)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func configureScene() {
        scene.scaleMode = .resizeFill
        scene.lanes = lanes
        scene.recorder = recorder
        scene.editorAudioEngine = engine
    }

    private func handlePicked(url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let copied = try SongImport.copyIntoDocuments(from: url)
            audioURL = copied
            createdAt = Date()
            offsetMs = 0
            recorder.setLanes(lanes)
            try engine.load(url: copied)
            statusText = "Loaded \(copied.lastPathComponent)"
            autosave(force: true)
        } catch {
            statusText = "Failed to import: \(error.localizedDescription)"
        }
    }

    private func autosave(force: Bool = false) {
        guard let audioURL else { return }
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)_user_\(lanes)lane.json"
        let saveURL = BeatmapStore.documentsURL(filename: fileName)
        let beatmap = Beatmap(
            version: 1,
            createdAt: createdAt,
            lanes: lanes,
            offsetMs: offsetMs,
            song: BeatmapSong(
                filename: audioURL.lastPathComponent,
                durationSec: engine.durationSec,
                sha256: nil
            ),
            notes: recorder.sortedNotes()
        )
        if force || !recorder.notes.isEmpty {
            try? BeatmapStore.save(beatmap, to: saveURL)
        }
    }
}

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
