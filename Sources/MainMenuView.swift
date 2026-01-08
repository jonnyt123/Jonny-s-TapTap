import SwiftUI

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
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.12),
                    Color(red: 0.08, green: 0.05, blue: 0.15),
                    Color(red: 0.12, green: 0.02, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 50) {
                // Logo at top
                VStack(spacing: 8) {
                    Text("JONNY'S")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .purple.opacity(glowIntensity), radius: 20)
                        .shadow(color: .pink.opacity(glowIntensity), radius: 30)
                    
                    Text("TAP TAP")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .kerning(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .yellow.opacity(glowIntensity), radius: 25)
                        .shadow(color: .orange.opacity(glowIntensity), radius: 35)
                        .shadow(color: .red.opacity(glowIntensity), radius: 45)
                        .overlay(
                            Text("TAP TAP")
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .kerning(4)
                                .foregroundStyle(.white.opacity(0.3))
                                .blur(radius: 2)
                                .offset(y: -2)
                        )
                }
                .scaleEffect(logoScale)
                .rotation3DEffect(
                    .degrees(sin(Date().timeIntervalSinceReferenceDate) * 5),
                    axis: (x: 0, y: 1, z: 0)
                )
                .padding(.vertical, 20)
                
                // Song selection - Scrollable
                VStack(alignment: .leading, spacing: 12) {
                    Text("SELECT SONG")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    HStack {
                        Image(systemName: "bitcoinsign.circle")
                            .foregroundStyle(.yellow)
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
                                LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(8)
                            .shadow(color: .blue.opacity(0.4), radius: 6)
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
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundStyle(song.accent)
                                                .font(.system(size: 20, weight: .bold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: song.primaryColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ).opacity( gameState.unlockedSongIDs.contains(song.id) ? 0.6 : 0.12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedSong.id == song.id ? song.accent : Color.white.opacity(0.15), lineWidth: 2.5)
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
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: song.accent.opacity(0.35), radius: 12, y: 4)
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
                        .background(Color.cyan.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)
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
                                        isAvailable ? (selectedDifficulty == difficulty ? .yellow : .white) : .gray
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        isAvailable ?
                                            (selectedDifficulty == difficulty ? Color.cyan.opacity(0.4) : Color.white.opacity(0.15))
                                            : Color.white.opacity(0.06)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedDifficulty == difficulty ? Color.yellow : Color.clear, lineWidth: 2)
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
                                colors: [.pink, .purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .purple.opacity(0.7), radius: 12, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
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
        .onAppear {
            // Animate logo
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                logoScale = 1.05
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }
}
