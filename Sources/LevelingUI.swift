import SwiftUI

struct LevelBadge: View {
    let level: Int

    var body: some View {
        Text("LV \(level)")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.80, green: 0.20, blue: 0.05),
                        Color(red: 0.35, green: 0.00, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
    }
}

struct LevelProgressBar: View {
    let totalXP: Int64
    let thresholds: [Int64]

    private var level: Int {
        LevelingSystem.level(for: totalXP, thresholds: thresholds)
    }

    private var progress: Double {
        let prev = thresholds[min(level, LevelingCurve.maxLevel)]
        let next = thresholds[min(level + 1, LevelingCurve.maxLevel)]
        if next <= prev { return 1.0 }
        return Double(totalXP - prev) / Double(next - prev)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LevelBadge(level: level)
                Text("\(totalXP) XP")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.1))
                        .frame(width: max(6, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                }
            }
            .frame(height: 10)
        }
    }
}
