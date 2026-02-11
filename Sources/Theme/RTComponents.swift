import SwiftUI

// MARK: - Buttons

struct RTPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RTTheme.Spacing.medium) {
                if let icon {
                    Image(systemName: icon)
                        .font(RTTheme.Fonts.body(18))
                }
                Text(title)
                    .font(RTTheme.Fonts.body(16))
            }
            .foregroundColor(RTTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RTTheme.Spacing.screen)
            .padding(.vertical, RTTheme.Spacing.medium)
            .background(
                LinearGradient(
                    colors: [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(RTTheme.Radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                    .stroke(RTTheme.Colors.primaryStroke.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(
                color: RTTheme.Colors.primaryShadow.opacity(0.7),
                radius: RTTheme.Shadow.primary().radius,
                y: RTTheme.Shadow.primary().y
            )
        }
    }
}

struct RTSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RTTheme.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(RTTheme.Fonts.body(16))
                }
                Text(title)
                    .font(RTTheme.Fonts.callout(13))
            }
            .foregroundColor(RTTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RTTheme.Spacing.section)
            .padding(.vertical, RTTheme.Spacing.sm)
            .background(RTTheme.Colors.surfaceMuted)
            .cornerRadius(RTTheme.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.card)
                    .stroke(RTTheme.Colors.surfaceStrokeStrong, lineWidth: 1)
            )
        }
    }
}

struct RTActionButton: View {
    enum Style {
        case primary   // red gradient (start game, continue-style)
        case success   // green
        case secondary // blue
        case gold      // continue / CTA
    }
    let title: String
    var icon: String? = nil
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RTTheme.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(RTTheme.Fonts.body(16))
                }
                Text(title)
                    .font(RTTheme.Fonts.body(16))
            }
            .foregroundColor(RTTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, RTTheme.Spacing.xl)
            .background(gradient)
            .cornerRadius(RTTheme.Radius.button)
            .shadow(color: shadowColor.opacity(0.6), radius: 10)
        }
    }

    private var gradient: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(
                colors: [RTTheme.Colors.primaryDarkerStart, RTTheme.Colors.primaryDarkerEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .success:
            return LinearGradient(
                colors: [RTTheme.Colors.successStart, RTTheme.Colors.successEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            return LinearGradient(
                colors: [RTTheme.Colors.blueStart, RTTheme.Colors.blueEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .gold:
            return LinearGradient(
                colors: [RTTheme.Colors.goldStart, RTTheme.Colors.goldEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary: return RTTheme.Colors.primaryShadow
        case .success: return RTTheme.Colors.successStart
        case .secondary: return RTTheme.Colors.blueStart
        case .gold: return RTTheme.Colors.goldStart
        }
    }
}

struct RTGhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RTTheme.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(RTTheme.Fonts.callout(12))
                }
                Text(title)
                    .font(RTTheme.Fonts.caption(12))
            }
            .foregroundColor(RTTheme.Colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, RTTheme.Spacing.md)
            .background(RTTheme.Colors.surfaceMuted)
            .cornerRadius(RTTheme.Radius.card)
        }
    }
}

// MARK: - Cards & panels

struct RTCard<Content: View>: View {
    let content: Content
    var strokeOpacity: Double = 0.15

    init(strokeOpacity: Double = 0.15, @ViewBuilder content: () -> Content) {
        self.strokeOpacity = strokeOpacity
        self.content = content()
    }

    var body: some View {
        content
            .padding(RTTheme.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: RTTheme.Radius.overlay)
                    .fill(RTTheme.Colors.surfaceMuted)
                    .overlay(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.overlay)
                            .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                    )
            )
    }
}

struct RTModalPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(RTTheme.Spacing.section)
            .frame(maxWidth: 360)
            .background(
                LinearGradient(
                    colors: [RTTheme.Colors.backgroundCardStart, RTTheme.Colors.backgroundCardEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(RTTheme.Radius.modal)
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.modal)
                    .stroke(RTTheme.Colors.surfaceStroke, lineWidth: 1)
            )
            .shadow(
                color: RTTheme.Shadow.modal().color,
                radius: RTTheme.Shadow.modal().radius,
                y: RTTheme.Shadow.modal().y
            )
    }
}

struct RTModalScrim: View {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        RTTheme.Colors.backgroundModalScrim
            .ignoresSafeArea()
            .onTapGesture { onTap?() }
    }
}

// MARK: - Section header

struct RTSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: RTTheme.Spacing.xs) {
            Text(title)
                .font(RTTheme.Fonts.headline(18))
                .foregroundColor(RTTheme.Colors.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(RTTheme.Fonts.caption(12))
                    .foregroundColor(RTTheme.Colors.textMuted)
            }
        }
    }
}

// MARK: - List row background (shop / menu)

struct RTListRowBackground: View {
    var body: some View {
        LinearGradient(
            colors: [RTTheme.Colors.backgroundShopRow, RTTheme.Colors.backgroundShopRowEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct RTListRowHeaderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, RTTheme.Colors.backgroundShopRowEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
