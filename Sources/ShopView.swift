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
    
    // Placeholder catalog mapped to existing song IDs
    private let catalog: [ShopItem] = [
        ShopItem(id: "test_song", title: "Test Song", price: 50),
        ShopItem(id: "crazy_train", title: "Crazy Train", price: 120),
        ShopItem(id: "i_will_not_bow", title: "I Will Not Bow", price: 100),
        ShopItem(id: "day_n_nite", title: "Day N Nite", price: 110),
        ShopItem(id: "blink182_see_you", title: "See You", price: 90),
        ShopItem(id: "madchild_chainsaw", title: "Chainsaw", price: 80),
        ShopItem(id: "hippie_sabotage_high", title: "High Enough", price: 95),
        ShopItem(id: "mgk_dont_let_me_go", title: "Don't Let Me Go", price: 105),
        ShopItem(id: "bizzy_banks_fonem", title: "On Fonem Grave", price: 85)
    ]
    
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
