import CoreGraphics
import SwiftUI

extension CGFloat {
    /// Safe value for layout: non-finite becomes 0.
    var safeFinite: CGFloat {
        isFinite ? self : 0
    }
}

/// Returns a size with width and height clamped to non-negative, finite values.
func clampSize(width: CGFloat, height: CGFloat) -> CGSize {
    CGSize(
        width: max(0, width.safeFinite),
        height: max(0, height.safeFinite)
    )
}
