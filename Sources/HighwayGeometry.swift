import CoreGraphics

struct HighwayGeometry {
    var topY: CGFloat
    var bottomY: CGFloat
    var topLeftX: CGFloat
    var topRightX: CGFloat
    var bottomLeftX: CGFloat
    var bottomRightX: CGFloat

    func laneCenterX(lane: Int, y: CGFloat, laneCount: Int = 4) -> CGFloat {
        guard laneCount > 0 else { return (topLeftX + topRightX) * 0.5 }
        let clampedLane = max(0, min(laneCount - 1, lane))
        let t = normalizedT(forY: y)
        let leftX = lerp(topLeftX, bottomLeftX, t)
        let rightX = lerp(topRightX, bottomRightX, t)
        let laneW = (rightX - leftX) / CGFloat(laneCount)
        return leftX + laneW * (CGFloat(clampedLane) + 0.5)
    }

    func normalizedT(forY y: CGFloat) -> CGFloat {
        let denom = bottomY - topY
        if abs(denom) < 0.0001 { return 1.0 }
        let t = (y - topY) / denom
        return clamp(t, 0, 1)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        max(minValue, min(maxValue, value))
    }
}
