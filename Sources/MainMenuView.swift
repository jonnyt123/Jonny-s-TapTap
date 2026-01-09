import SwiftUI
import UIKit

struct MainMenuView: View {
    @ObservedObject var gameState: GameState
    @Binding var isPlaying: Bool
    @Binding var selectedDifficulty: Difficulty
    @Binding var selectedSong: SongMetadata
    var availableDifficulties: Set<Difficulty>
    @State private var logoScale: CGFloat = 0.8
    @State private var glowIntensity: Double = 0.5
    @State private var showDifficultyMenu = false
    @State private var showShop = false
    
    var body: some View {
        ZStack {
            // Heavy-metal background image - fills entire screen
            Color.black
                .ignoresSafeArea()
            
            if let bgImage = UIImage(named: "main_menu_bg") ?? loadBackgroundImage() {
                GeometryReader { geometry in
                    Image(uiImage: bgImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                // Fallback gradient if image not found
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.02),
                        Color(red: 0.06, green: 0.06, blue: 0.07),
                        Color(red: 0.18, green: 0.00, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // Dark overlay for better text readability
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .blendMode(.multiply)
            
            VStack(spacing: 30) {
                // Spacer to push content down past the logo in background
                Spacer()
                    .frame(height: 280)
                
                // Song selection - Scrollable
                VStack(alignment: .leading, spacing: 12) {
                    Text("SELECT SONG")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 4)
                        .padding(.horizontal)
                    HStack {
                        Image(systemName: "flame.circle.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.1))
                        Text("Tap Coins: \(gameState.tapCoins)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Button(action: { showShop = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "cart")
                                Text("Shop")
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [
                                    Color(red: 0.20, green: 0.20, blue: 0.22),
                                    Color(red: 0.35, green: 0.00, blue: 0.05)
                                ], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.7, green: 0.0, blue: 0.05).opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color(red: 0.6, green: 0.0, blue: 0.0).opacity(0.5), radius: 6)
                        }
                    }
                    .padding(.horizontal)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 10) {
                            ForEach(SongMetadata.library) { song in
                                Button(action: {
                                    let isUnlocked = gameState.unlockedSongIDs.contains(song.id)
                                    if isUnlocked { selectedSong = song }
                                }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            let isUnlocked = gameState.unlockedSongIDs.contains(song.id)
                                            Text(isUnlocked ? song.title.uppercased() : "LOCKED")
                                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            Text(song.artist)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("BPM \(Int(song.bpm))")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.8))
                                            Text("\(song.lanes)-LANE")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                        if selectedSong.id == song.id {
                                            Image(systemName: "bolt.circle.fill")
                                                .foregroundStyle(Color(red: 0.85, green: 0.0, blue: 0.05))
                                                .font(.system(size: 20, weight: .bold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: metalCardColors(for: song, unlocked: gameState.unlockedSongIDs.contains(song.id)),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ).opacity( gameState.unlockedSongIDs.contains(song.id) ? 0.9 : 0.25)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedSong.id == song.id ? Color(red: 0.8, green: 0.0, blue: 0.05) : Color.white.opacity(0.12), lineWidth: 2.0)
                                    )
                                    .overlay {
                                        if !gameState.unlockedSongIDs.contains(song.id) {
                                            ZStack {
                                                Color.black.opacity(0.4)
                                                    .cornerRadius(12)
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 26, weight: .bold))
                                                    .foregroundStyle(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                    .cornerRadius(12)
                                    .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.8), radius: 10, y: 4)
                                }
                                .padding(.horizontal)
                                .disabled(!gameState.unlockedSongIDs.contains(song.id))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollIndicators(.visible)
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 12)
                
                // Controls at bottom
                VStack(spacing: 10) {
                    // Difficulty button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showDifficultyMenu.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: showDifficultyMenu ? "chevron.up" : "chevron.down")
                                .font(.system(size: 16, weight: .bold))
                            Text(showDifficultyMenu ? "HIDE" : "DIFFICULTY: \(selectedDifficulty.rawValue.uppercased())")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.7, green: 0.0, blue: 0.05).opacity(0.8), lineWidth: 1.5)
                        )
                    }
                    
                    // Difficulty selection (if visible)
                    if showDifficultyMenu {
                        HStack(spacing: 6) {
                            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                let isAvailable = availableDifficulties.contains(difficulty)
                                Button(action: {
                                    guard isAvailable else { return }
                                    selectedDifficulty = difficulty
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showDifficultyMenu = false
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Text(difficulty.rawValue.prefix(1))
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                        Text(difficulty.rawValue)
                                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(
                                        isAvailable ? (selectedDifficulty == difficulty ? Color(red: 1.0, green: 0.2, blue: 0.2) : .white) : .gray
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        isAvailable ?
                                            (selectedDifficulty == difficulty ? Color(red: 0.35, green: 0.00, blue: 0.05).opacity(0.6) : Color.white.opacity(0.08))
                                            : Color.white.opacity(0.05)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedDifficulty == difficulty ? Color(red: 0.8, green: 0.0, blue: 0.05) : Color.clear, lineWidth: 2)
                                    )
                                }
                                .disabled(!isAvailable)
                            }
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                    
                    // Start game button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            isPlaying = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("START GAME")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.65, green: 0.00, blue: 0.05),
                                    Color(red: 0.35, green: 0.00, blue: 0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(red: 0.6, green: 0.0, blue: 0.0).opacity(0.7), radius: 12, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.8, green: 0.0, blue: 0.05).opacity(0.9), lineWidth: 1.5)
                        )
                    }
                    .disabled(!gameState.unlockedSongIDs.contains(selectedSong.id))
                }
                .padding(.bottom, 40)
                .padding(.horizontal)
            }
            .sheet(isPresented: $showShop) {
                ShopView(gameState: gameState)
            }
        }
    }
}

private func loadBackgroundImage() -> UIImage? {
    // Try to load from bundle
    if let path = Bundle.main.path(forResource: "main_menu_bg", ofType: "jpg"),
       let image = UIImage(contentsOfFile: path) {
        return image
    }
    if let path = Bundle.main.path(forResource: "main_menu_bg", ofType: "png"),
       let image = UIImage(contentsOfFile: path) {
        return image
    }
    return nil
}

// MARK: - Metal Theme Helpers

private func metalTitleFont(_ size: CGFloat) -> Font {
    if UIFont(name: "MetalDisplay", size: size) != nil {
        return .custom("MetalDisplay", size: size)
    } else if UIFont(name: "JonnysTapTap", size: size) != nil {
        return .custom("JonnysTapTap", size: size)
    } else if UIFont(name: "Copperplate-Bold", size: size) != nil {
        return .custom("Copperplate-Bold", size: size)
    }
    return .system(size: size, weight: .black, design: .default)
}

private func metalBrandFont(_ size: CGFloat) -> Font {
    if UIFont(name: "MetalDisplay", size: size) != nil {
        return .custom("MetalDisplay", size: size)
    } else if UIFont(name: "JonnysTapTap", size: size) != nil {
        return .custom("JonnysTapTap", size: size)
    } else if UIFont(name: "Copperplate", size: size) != nil {
        return .custom("Copperplate", size: size)
    }
    return .system(size: size, weight: .heavy, design: .default)
}

private func metalCardColors(for song: SongMetadata, unlocked: Bool) -> [Color] {
    if !unlocked {
        return [Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.18, green: 0.00, blue: 0.03)]
    }
    if song.lanes == 4 {
        return [Color(red: 0.15, green: 0.15, blue: 0.18), Color(red: 0.40, green: 0.00, blue: 0.06)]
    }
    if song.bpm >= 120 {
        return [Color(red: 0.14, green: 0.14, blue: 0.17), Color(red: 0.05, green: 0.20, blue: 0.40)]
    }
    return [Color(red: 0.14, green: 0.14, blue: 0.17), Color(red: 0.22, green: 0.00, blue: 0.28)]
}

private struct MetalStripes: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let count = Int(width / 8)
            ZStack {
                ForEach(0..<(count + 20), id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 2)
                        .offset(x: CGFloat(i) * 8)
                }
            }
            .rotationEffect(.degrees(12))
            .offset(y: -geo.size.height * 0.2)
        }
        .allowsHitTesting(false)
    }
}

private struct MetalSheen: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.15), Color.white.opacity(0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }
}
