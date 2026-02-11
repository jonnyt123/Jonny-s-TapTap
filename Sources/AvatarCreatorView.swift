import SwiftUI

struct AvatarCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGender: AvatarGender = AvatarStore.shared.gender
    @State private var previewImage: UIImage = AvatarStore.shared.currentAvatarImage()

    var body: some View {
        ZStack {
            RTTheme.Colors.backgroundDarkStart
                .ignoresSafeArea()

            VStack(spacing: RTTheme.Spacing.block) {
                Text("CHOOSE AVATAR")
                    .font(RTTheme.Fonts.title(24))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                    .padding(.top, RTTheme.Spacing.screen)

                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: RTTheme.Radius.panel))
                    .overlay(
                        RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                            .stroke(RTTheme.Colors.surfaceStroke, lineWidth: 2)
                    )
                    .padding(.vertical, RTTheme.Spacing.lg)

                HStack(spacing: RTTheme.Spacing.lg) {
                    avatarCard(gender: .male)
                    avatarCard(gender: .female)
                }
                .padding(.horizontal, RTTheme.Spacing.screen)

                Spacer(minLength: RTTheme.Spacing.block)

                Button(action: {
                    AvatarStore.shared.setGender(selectedGender)
                    dismiss()
                }) {
                    Text("DONE")
                        .font(RTTheme.Fonts.headline(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RTTheme.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: RTTheme.Radius.button)
                                .fill(RTTheme.Colors.blueStart)
                        )
                }
                .padding(.horizontal, RTTheme.Spacing.screen)
                .padding(.bottom, RTTheme.Spacing.screen)
            }
        }
        .onAppear {
            selectedGender = AvatarStore.shared.gender
            previewImage = AvatarStore.shared.currentAvatarImage()
        }
    }

    private func avatarCard(gender: AvatarGender) -> some View {
        let isSelected = selectedGender == gender
        let image = gender == .female
            ? AvatarStore.shared.renderAvatarImage(config: AvatarConfig(gender: .female))
            : AvatarStore.shared.renderAvatarImage(config: AvatarConfig(gender: .male))
        return Button(action: {
            selectedGender = gender
            AvatarStore.shared.setGender(gender)
            previewImage = AvatarStore.shared.currentAvatarImage()
        }) {
            VStack(spacing: RTTheme.Spacing.md) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 140, maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: RTTheme.Radius.card))
                Text(gender == .male ? "MALE" : "FEMALE")
                    .font(RTTheme.Fonts.headline(14))
                    .foregroundStyle(RTTheme.Colors.textPrimary)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(RTTheme.Colors.accentHighlight)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(RTTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                    .fill(LinearGradient(
                        colors: isSelected
                            ? [RTTheme.Colors.primaryDarkStart, RTTheme.Colors.primaryDarkEnd]
                            : [RTTheme.Colors.backgroundCardStart, RTTheme.Colors.backgroundCardEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RTTheme.Radius.panel)
                    .stroke(isSelected ? RTTheme.Colors.primaryStroke : RTTheme.Colors.surfaceStroke, lineWidth: isSelected ? 3 : 1)
            )
            .shadow(color: isSelected ? RTTheme.Colors.primaryStroke.opacity(0.6) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

}
