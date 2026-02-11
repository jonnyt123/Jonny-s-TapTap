import SwiftUI
import UIKit

struct SongRowView: View {
    let song: Song
    let isSelected: Bool
    let onTap: () -> Void

    private static let cardHeight: CGFloat = 92
    private static let leftPadding: CGFloat = 16
    private static let cardAssetName = "song_card"

    var body: some View {
        Button {
            RTHaptics.impact()
            onTap()
        } label: {
            ZStack {
                Image(Self.cardAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: Self.cardHeight)
                    .clipped()

                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(song.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(song.isLocked ? Color.white.opacity(0.5) : .white)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(song.isLocked ? Color.white.opacity(0.5) : Color.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Group {
                            if song.isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                            } else {
                                EmptyView()
                            }
                        }
                        durationText
                        difficultyIndicator
                    }
                    .padding(.trailing, 14)
                }
                .padding(.leading, Self.leftPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                            .shadow(radius: 8)
                    } else {
                        EmptyView()
                    }
                }
            }
            .frame(height: Self.cardHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(song.isLocked ? 0.92 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.title), \(song.artist)")
        .accessibilityHint(song.isLocked ? "Locked" : "Tap to select")
    }

    private var difficultyIndicator: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(level <= song.difficulty ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 10)
            }
        }
    }

    private var durationText: some View {
        let m = Int(song.duration) / 60
        let s = Int(song.duration) % 60
        return Text(String(format: "%d:%02d", m, s))
            .font(.caption)
            .foregroundColor(song.isLocked ? Color.white.opacity(0.5) : Color.white.opacity(0.85))
    }
}
