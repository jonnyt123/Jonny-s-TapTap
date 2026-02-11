import SwiftUI

// MARK: - Design tokens (normalized from existing UI)

enum RTTheme {

    // MARK: - Colors
    enum Colors {
        // Primary / CTA (red-orange)
        static let primaryStart = Color(red: 0.90, green: 0.35, blue: 0.08)
        static let primaryEnd = Color(red: 0.65, green: 0.00, blue: 0.05)
        static let primaryStroke = Color(red: 0.80, green: 0.00, blue: 0.05)
        static let primaryShadow = Color(red: 0.60, green: 0.00, blue: 0.00)

        // Darker primary (buttons, modals)
        static let primaryDarkStart = Color(red: 0.75, green: 0.08, blue: 0.10)
        static let primaryDarkEnd = Color(red: 0.45, green: 0.02, blue: 0.08)
        static let primaryDarkerStart = Color(red: 0.65, green: 0.00, blue: 0.05)
        static let primaryDarkerEnd = Color(red: 0.35, green: 0.00, blue: 0.05)

        // Accent / coin / orange
        static let accentOrange = Color(red: 1.0, green: 0.45, blue: 0.12)
        static let accentOrangeLight = Color(red: 1.0, green: 0.60, blue: 0.20)
        static let accentAmber = Color(red: 1.0, green: 0.75, blue: 0.20)
        static let accentHighlight = Color(red: 1.0, green: 0.55, blue: 0.15)

        // Success / green
        static let successStart = Color(red: 0.20, green: 0.80, blue: 0.20)
        static let successEnd = Color(red: 0.10, green: 0.60, blue: 0.10)

        // Blue / secondary
        static let blueStart = Color(red: 0.20, green: 0.60, blue: 1.0)
        static let blueEnd = Color(red: 0.10, green: 0.40, blue: 0.80)

        // Gold / continue / S grade
        static let goldStart = Color(red: 0.95, green: 0.70, blue: 0.20)
        static let goldEnd = Color(red: 0.90, green: 0.50, blue: 0.10)

        // Selected / danger red
        static let selectedRed = Color(red: 0.85, green: 0.15, blue: 0.12)
        static let selectedRedBright = Color(red: 1.0, green: 0.20, blue: 0.20)
        static let selectedStroke = Color(red: 0.95, green: 0.35, blue: 0.20)

        // Backgrounds
        static let backgroundDarkStart = Color(red: 0.05, green: 0.05, blue: 0.15)
        static let backgroundDarkEnd = Color(red: 0.10, green: 0.05, blue: 0.20)
        static let backgroundCardStart = Color(red: 0.12, green: 0.08, blue: 0.14)
        static let backgroundCardEnd = Color(red: 0.05, green: 0.03, blue: 0.05)
        static let backgroundShopRow = Color(red: 0.06, green: 0.06, blue: 0.08)
        static let backgroundShopRowEnd = Color(red: 0.20, green: 0.00, blue: 0.05)
        static let backgroundModalScrim = Color.black.opacity(0.65)

        // Surfaces
        static let surfaceSubtle = Color.white.opacity(0.05)
        static let surfaceMuted = Color.white.opacity(0.08)
        static let surfaceStroke = Color.white.opacity(0.12)
        static let surfaceStrokeStrong = Color.white.opacity(0.18)
        static let surfaceStrokeLight = Color.white.opacity(0.15)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.85)
        static let textMuted = Color.white.opacity(0.70)
        static let textFaded = Color.white.opacity(0.50)
        static let textDisabled = Color.gray

        // Owned / success tint
        static let ownedGreen = Color(red: 0.70, green: 1.0, blue: 0.20)
        static let cardUserBeatmap = Color(red: 0.30, green: 0.10, blue: 0.05)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let medium: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
        static let xxl: CGFloat = 16
        static let section: CGFloat = 18
        static let block: CGFloat = 20
        static let screen: CGFloat = 24
        static let large: CGFloat = 40
    }

    // MARK: - Corner radius
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let card: CGFloat = 10
        static let button: CGFloat = 12
        static let panel: CGFloat = 14
        static let modal: CGFloat = 18
        static let overlay: CGFloat = 20
    }

    // MARK: - Shadows
    enum Shadow {
        static func primary(color: Color = Colors.primaryShadow, radius: CGFloat = 12, y: CGFloat = 6) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (color.opacity(0.7), radius, y)
        }
        static func card(color: Color = .black) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (color.opacity(0.8), 10, 4)
        }
        static func glow(color: Color, radius: CGFloat = 10) -> (color: Color, radius: CGFloat) {
            (color.opacity(0.6), radius)
        }
        static func modal() -> (color: Color, radius: CGFloat, y: CGFloat) {
            (.black.opacity(0.6), 12, 6)
        }
    }

    // MARK: - Typography (semantic; preserves .rounded where used)
    enum Fonts {
        static func title(_ size: CGFloat = 32, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func headline(_ size: CGFloat = 18, weight: Font.Weight = .heavy) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func body(_ size: CGFloat = 16, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func callout(_ size: CGFloat = 14, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func caption(_ size: CGFloat = 12, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func label(_ size: CGFloat = 10, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func small(_ size: CGFloat = 9, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    // MARK: - Animation
    enum Animation {
        static let quick: Double = 0.15
        static let standard: Double = 0.3
        static let emphasis: Double = 0.6
        static let long: Double = 0.8
        static var quickEaseOut: SwiftUI.Animation { .easeOut(duration: quick) }
        static var standardEaseOut: SwiftUI.Animation { .easeOut(duration: standard) }
        static var emphasisEaseOut: SwiftUI.Animation { .easeOut(duration: emphasis) }
        static var spring: SwiftUI.Animation { .spring(response: 0.4, dampingFraction: 0.6) }
        static var springTight: SwiftUI.Animation { .spring(response: 0.4, dampingFraction: 0.7) }
    }
}
