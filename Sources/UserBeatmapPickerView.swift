import SwiftUI

struct UserBeatmapEntry: Identifiable {
    let id = UUID()
    let url: URL
    let beatmap: Beatmap
}

struct UserBeatmapPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Beatmap, URL) -> Void

    @State private var entries: [UserBeatmapEntry] = []

    var body: some View {
        NavigationView {
            List(entries) { entry in
                Button(action: {
                    onSelect(entry.beatmap, entry.url)
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.beatmap.song.filename)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("\(entry.beatmap.lanes)-lane • \(entry.beatmap.notes.count) notes")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("User Beatmaps")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                entries = loadEntries()
            }
        }
    }

    private func loadEntries() -> [UserBeatmapEntry] {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let urls = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else {
            return []
        }
        let beatmapFiles = urls.filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.contains("_user_") }
        var results: [UserBeatmapEntry] = []
        for url in beatmapFiles {
            if let beatmap = try? BeatmapStore.load(from: url) {
                results.append(UserBeatmapEntry(url: url, beatmap: beatmap))
            }
        }
        return results.sorted { $0.beatmap.createdAt > $1.beatmap.createdAt }
    }
}
