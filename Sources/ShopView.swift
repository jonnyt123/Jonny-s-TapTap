import SwiftUI

struct ShopItem: Identifiable {
    let id: String
    let title: String
    let price: Int
}

struct ShopView: View {
    @ObservedObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var justPurchased: String? = nil
    @State private var showCoinAnim = false
    
    // Dynamically generate catalog from SongMetadata.library (except default song)
    private var catalog: [ShopItem] {
        // Assign prices based on order or custom logic
        let prices = [50, 120, 100, 110, 90, 80, 95, 105, 85, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230]
        return SongMetadata.library.enumerated().compactMap { (idx, song) in
            // Don't sell the default song (usually hallelujah)
            if song.id == "hallelujah" { return nil }
            let price = idx < prices.count ? prices[idx] : 100 + idx * 10
            return ShopItem(id: song.id, title: song.title, price: price)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("Tap Coins: \(gameState.tapCoins)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Button("Close") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                }
                
                Section(header: Text("Song Catalog")) {
                    ForEach(catalog) { item in
                        let owned = gameState.unlockedSongIDs.contains(item.id)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle( owned ? .white : .white.opacity(0.6) )
                                Text(owned ? "Owned" : "Price: \(item.price)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle( owned ? .green : .white.opacity(0.7) )
                            }
                            Spacer()
                            if owned {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 18))
                            } else {
                                Button(action: { purchase(item) }) {
                                    Text("Buy")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(gameState.tapCoins < item.price)
                                .overlay {
                                    if justPurchased == item.id && showCoinAnim {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bitcoinsign.circle.fill")
                                                .foregroundStyle(.yellow)
                                            Text("✓ Unlocked")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(.yellow)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.2))
                                        .cornerRadius(6)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .navigationTitle("Shop")
            .background(
                LinearGradient(colors: [.black, Color(red: 0.08, green: 0.05, blue: 0.15)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
    }
    
    private func purchase(_ item: ShopItem) {
        guard !gameState.unlockedSongIDs.contains(item.id) else { return }
        guard gameState.tapCoins >= item.price else { return }
        gameState.tapCoins -= item.price
        gameState.unlockedSongIDs.insert(item.id)
        gameState.saveProgress()
        justPurchased = item.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showCoinAnim = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            justPurchased = nil
            showCoinAnim = false
        }
    }
}
