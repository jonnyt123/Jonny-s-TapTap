import SwiftUI
import UniformTypeIdentifiers

struct UserBeatmapEntry: Identifiable {
    let id = UUID()
    let url: URL
    let beatmap: Beatmap
}

// MARK: - User Beatmaps View (setlist-style)

struct UserBeatmapPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Beatmap, URL) -> Void
    /// When set, "Create Beatmap" calls this instead of dismissing. Caller should dismiss this sheet then present the editor.
    var onCreateBeatmapRequested: (() -> Void)? = nil

    @State private var entries: [UserBeatmapEntry] = []
    @State private var selectedEntry: UserBeatmapEntry?
    @State private var showImportPicker = false
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: UserBeatmapEntry?
    @State private var backgroundUnavailable = false

    private var docsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerBar
                statsBar
                primaryActionsBar
                if entries.isEmpty {
                    emptyState
                } else {
                    beatmapList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                createBeatmapFooter
            }
        }
        .onAppear {
            backgroundUnavailable = (UIImage(named: "SetlistBackground") == nil)
            reloadEntries()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    let dest = docsURL.appendingPathComponent(url.lastPathComponent)
                    try? data.write(to: dest, options: .atomic)
                    reloadEntries()
                }
            case .failure:
                break
            }
        }
        .confirmationDialog("Delete Beatmap?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let e = entryToDelete {
                    try? FileManager.default.removeItem(at: e.url)
                    if selectedEntry?.id == e.id { selectedEntry = nil }
                    reloadEntries()
                }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            if let e = entryToDelete {
                Text("Remove \"\(beatmapDisplayName(e.beatmap))\"? This cannot be undone.")
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.04, blue: 0.10), Color(red: 0.04, green: 0.02, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            if !backgroundUnavailable {
                Image("SetlistBackground")
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.5))
                    .clipped()
            }
        }
        .ignoresSafeArea()
    }

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    RTHaptics.impact()
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("BACK")
                            .font(.system(size: 13, weight: .bold, design: .default))
                    }
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .pencilTextStyle(color: RTTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                Spacer()
                Text("USER BEATMAPS")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .pencilTextStyle(color: RTTheme.Colors.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                Spacer()
                Color.clear.frame(width: 64, height: 36)
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 6)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 1)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var statsBar: some View {
        HStack(spacing: RTTheme.Spacing.lg) {
            statItem(label: "Total", value: "\(entries.count)")
            statItem(label: "Last imported", value: lastImportedText)
            statItem(label: "Storage", value: storageUsedText)
        }
        .font(RTTheme.Fonts.caption(11))
        .foregroundStyle(RTTheme.Colors.textMuted)
        .padding(.horizontal, RTTheme.Spacing.screen)
        .padding(.vertical, RTTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .foregroundStyle(RTTheme.Colors.textFaded)
            Text(value)
                .foregroundStyle(RTTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastImportedText: String {
        guard let latest = entries.first?.beatmap.createdAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: latest)
    }

    private var storageUsedText: String {
        let fm = FileManager.default
        var total: Int64 = 0
        for entry in entries {
            if let size = try? fm.attributesOfItem(atPath: entry.url.path)[.size] as? Int64 {
                total += size
            }
        }
        let kb = total / 1024
        if kb >= 1024 { return String(format: "%.1f MB", Double(total) / 1_048_576) }
        return "\(kb) KB"
    }

    private var primaryActionsBar: some View {
        HStack(spacing: RTTheme.Spacing.md) {
            Button(action: {
                RTHaptics.impact()
                showImportPicker = true
            }) {
                Label("Import Beatmap", systemImage: "square.and.arrow.down")
                    .font(RTTheme.Fonts.callout(14))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RTTheme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .fill(LinearGradient(
                                colors: [RTTheme.Colors.primaryDarkStart, RTTheme.Colors.primaryDarkEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .stroke(RTTheme.Colors.primaryStroke.opacity(0.8), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button(action: {
                RTHaptics.impact()
                if let onCreate = onCreateBeatmapRequested {
                    onCreate()
                } else {
                    dismiss()
                }
            }) {
                Label("Create Beatmap", systemImage: "plus.circle.fill")
                    .font(RTTheme.Fonts.callout(14))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RTTheme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .fill(LinearGradient(
                                colors: [RTTheme.Colors.primaryDarkStart, RTTheme.Colors.primaryDarkEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .stroke(RTTheme.Colors.primaryStroke.opacity(0.8), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
            .padding(.horizontal, RTTheme.Spacing.screen)
            .padding(.vertical, RTTheme.Spacing.md)
            .background(Color.black.opacity(0.18))
    }

    private var createBeatmapFooter: some View {
        Button(action: {
            RTHaptics.impact()
            if let onCreate = onCreateBeatmapRequested {
                onCreate()
            } else {
                dismiss()
            }
        }) {
            HStack(spacing: RTTheme.Spacing.medium) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Create Beatmap")
                    .font(RTTheme.Fonts.headline(16))
            }
            .foregroundStyle(RTTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, RTTheme.Spacing.medium)
            .background(
                LinearGradient(
                    colors: [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                    .stroke(RTTheme.Colors.primaryStroke.opacity(0.9), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, RTTheme.Spacing.screen)
        .padding(.top, RTTheme.Spacing.md)
        .padding(.bottom, RTTheme.Spacing.screen)
        .background(Color.black.opacity(0.25))
    }

    private var beatmapList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                ForEach(entries) { entry in
                    BeatmapCardView(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        onTap: {
                            RTHaptics.impact()
                            selectedEntry = entry
                        },
                        onDoubleTap: {
                            RTHaptics.impact()
                            onSelect(entry.beatmap, entry.url)
                            dismiss()
                        },
                        onPlay: {
                            RTHaptics.impact()
                            onSelect(entry.beatmap, entry.url)
                            dismiss()
                        },
                        onEdit: { },
                        onDelete: {
                            entryToDelete = entry
                            showDeleteConfirm = true
                        }
                    )
                }
            }
            .padding(.horizontal, RTTheme.Spacing.screen)
            .padding(.vertical, RTTheme.Spacing.md)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: RTTheme.Spacing.block) {
            Spacer(minLength: 40)
            Text("No beatmaps yet")
                .font(RTTheme.Fonts.title(22))
                .foregroundStyle(RTTheme.Colors.textPrimary)
            Text("Import a beatmap file or create one in the Beatmap Editor from the main menu.")
                .font(RTTheme.Fonts.callout(14))
                .foregroundStyle(RTTheme.Colors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: {
                RTHaptics.impact()
                showImportPicker = true
            }) {
                Text("Import Beatmap")
                    .font(RTTheme.Fonts.headline(16))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .padding(.horizontal, RTTheme.Spacing.screen)
                    .padding(.vertical, RTTheme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .fill(LinearGradient(
                                colors: [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                            .stroke(RTTheme.Colors.primaryStroke.opacity(0.9), lineWidth: 1)
                    )
            }
            .padding(.top, 8)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func beatmapDisplayName(_ beatmap: Beatmap) -> String {
        let base = beatmap.song.filename
        return (base as NSString).deletingPathExtension
    }

    private func reloadEntries() {
        entries = loadEntries()
    }

    private func loadEntries() -> [UserBeatmapEntry] {
        let fm = FileManager.default
        let docs = docsURL
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

// MARK: - Beatmap Card

struct BeatmapCardView: View {
    let entry: UserBeatmapEntry
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var beatmap: Beatmap { entry.beatmap }
    private var displayName: String {
        (beatmap.song.filename as NSString).deletingPathExtension
    }

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(RTTheme.Animation.quickEaseOut, value: isSelected)
        .highPriorityGesture(
            TapGesture(count: 2).onEnded { _ in onDoubleTap() }
        )
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(RTTheme.Fonts.headline(16))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(beatmap.lanes)-lane • \(beatmap.notes.count) notes • BPM —")
                    .font(RTTheme.Fonts.caption(11))
                    .foregroundStyle(RTTheme.Colors.textMuted)
                HStack(spacing: 6) {
                    difficultyChip
                    Text("Created \(shortDate(beatmap.createdAt))")
                        .font(RTTheme.Fonts.label(10))
                        .foregroundStyle(RTTheme.Colors.textFaded)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RTTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    colors: [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .overlay(Circle().stroke(RTTheme.Colors.primaryStroke.opacity(0.8), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(RTTheme.Colors.textMuted)
                }
            }
        }
        .padding(RTTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                .fill(isSelected ? Color(white: 0.22) : Color(white: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                .stroke(isSelected ? RTTheme.Colors.primaryStroke : Color.white.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: RTTheme.Radius.medium)
            .fill(Color.white.opacity(0.1))
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(RTTheme.Colors.textMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.medium)
                    .stroke(RTTheme.Colors.surfaceStroke, lineWidth: 1)
            )
    }

    private var difficultyChip: some View {
        Text("\(beatmap.lanes)L")
            .font(RTTheme.Fonts.label(10))
            .foregroundStyle(RTTheme.Colors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.black.opacity(0.35))
            )
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}
