import SwiftUI

struct ShopItem: Identifiable {
    let id: String
    let title: String
    let artist: String
    let price: Int
}

struct ShopView: View {
    @ObservedObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var justPurchased: String? = nil
    @State private var showCoinAnim = false
    /// Prevents double-tap / race: disable all Buy buttons while a purchase is in progress.
    @State private var isPurchasing = false

    /// Catalog: all purchasable songs with prices from EconomyConfig (excludes free default track).
    private var catalog: [ShopItem] {
        SongMetadata.library.compactMap { song in
            guard EconomyConfig.isPurchasable(songId: song.id) else { return nil }
            let price = EconomyConfig.price(forSongId: song.id)
            return ShopItem(id: song.id, title: song.title, artist: song.artist, price: price)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(RTTheme.Colors.accentOrange)
                        Text("Tap Coins: \(gameState.tapCoins)")
                            .font(RTTheme.Fonts.callout(14))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                        Text("(earned by playing)")
                            .font(RTTheme.Fonts.caption(12))
                            .foregroundStyle(RTTheme.Colors.textMuted)
                        Spacer()
                        Button("Close") { RTHaptics.impact(); dismiss() }
                            .font(RTTheme.Fonts.callout(14))
                            .foregroundStyle(RTTheme.Colors.textPrimary)
                            .padding(.horizontal, RTTheme.Spacing.lg)
                            .padding(.vertical, RTTheme.Spacing.sm)
                            .background(RTTheme.Colors.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: RTTheme.Radius.card))
                            .overlay(RoundedRectangle(cornerRadius: RTTheme.Radius.card).stroke(RTTheme.Colors.surfaceStrokeStrong, lineWidth: 1))
                    }
                    .listRowBackground(RTListRowHeaderBackground())
                }
                
                Section(header: Text("Song Catalog")) {
                    ForEach(catalog) { item in
                        let owned = gameState.unlockedSongIDs.contains(item.id)
                        HStack {
                            VStack(alignment: .leading, spacing: RTTheme.Spacing.xs) {
                                Text(item.title)
                                    .font(shopFont(18, weight: .heavy))
                                    .foregroundStyle(owned ? RTTheme.Colors.textPrimary : RTTheme.Colors.textMuted)
                                Text(item.artist)
                                    .font(shopFont(12, weight: .bold))
                                    .foregroundStyle(RTTheme.Colors.textMuted)
                                Text(owned ? "Owned" : "\(item.price) Tap Coins")
                                    .font(shopFont(12, weight: .semibold))
                                    .foregroundStyle(owned ? RTTheme.Colors.ownedGreen : RTTheme.Colors.textMuted)
                            }
                            Spacer()
                            if owned {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(RTTheme.Colors.ownedGreen)
                                    .font(.system(size: 18))
                            } else {
                                Button(action: { purchase(item) }) {
                                    Text("Unlock")
                                        .font(shopFont(14, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isPurchasing || gameState.tapCoins < item.price)
                                .overlay {
                                    if justPurchased == item.id && showCoinAnim {
                                        HStack(spacing: RTTheme.Spacing.xs) {
                                            Image(systemName: "bitcoinsign.circle.fill")
                                                .foregroundStyle(RTTheme.Colors.accentOrange)
                                            Text("✓ Unlocked")
                                                .font(shopFont(12, weight: .bold))
                                                .foregroundStyle(RTTheme.Colors.accentAmber)
                                        }
                                        .padding(.horizontal, RTTheme.Spacing.md)
                                        .padding(.vertical, RTTheme.Spacing.xs)
                                        .background(RTTheme.Colors.cardUserBeatmap)
                                        .cornerRadius(RTTheme.Radius.small)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .listRowBackground(RTListRowBackground())
                    }
                }
            }
            .navigationTitle("Shop")
            .scrollContentBackground(.hidden)
            .background(
                ZStack {
                    Image("death_metal_texture")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.8)
                        .ignoresSafeArea()
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), RTTheme.Colors.backgroundShopRowEnd.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            )
        }
    }

    private func shopFont(_ size: CGFloat, weight: Font.Weight) -> Font {
        if UIFont(name: "JonnysTapTap", size: size) != nil {
            return .custom("JonnysTapTap", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    private func purchase(_ item: ShopItem) {
        guard !isPurchasing else { return }
        guard item.price > 0 else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        guard gameState.purchaseSong(songId: item.id, price: item.price) else { return }
        gameState.saveProgress()
        RTHaptics.success()
        justPurchased = item.id
        withAnimation(RTTheme.Animation.springTight) {
            showCoinAnim = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            justPurchased = nil
            showCoinAnim = false
        }
    }
}
