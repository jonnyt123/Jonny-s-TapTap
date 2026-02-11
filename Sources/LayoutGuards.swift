import CoreGraphics
import Foundation
import os.log

@inline(__always)
func isFinitePositive(_ v: CGFloat) -> Bool {
    v.isFinite && v > 0
}

@inline(__always)
func safePositive(_ v: CGFloat, fallback: CGFloat = 1) -> CGFloat {
    guard v.isFinite else { return fallback }
    return max(v, fallback)
}

@inline(__always)
func safeSize(_ size: CGSize, fallback: CGSize = CGSize(width: 1, height: 1)) -> CGSize {
    CGSize(
        width: safePositive(size.width, fallback: fallback.width),
        height: safePositive(size.height, fallback: fallback.height)
    )
}

@inline(__always)
func assertValidSize(_ size: CGSize, context: String) {
    if !(size.width.isFinite && size.height.isFinite && size.width >= 0 && size.height >= 0) {
        let desc = String(format: "%.2f x %.2f", size.width, size.height)
        os_log("❌ Invalid size in %{public}@: %{public}@", context, desc)
    }
}
