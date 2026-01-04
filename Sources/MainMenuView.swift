import SwiftUI

struct MainMenuView: View {
    @Binding var isPlaying: Bool
    @Binding var selectedDifficulty: Difficulty
    @Binding var selectedSong: SongMetadata
    @State private var logoScale: CGFloat = 0.8
    @State private var glowIntensity: Double = 0.5
    @State private var showDifficultyMenu = false
    
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
                Spacer()
                
                // Logo
                VStack(spacing: 8) {
                    Text("JONNY'S")
                        .font(.system(size: 42, weight: .black, design: .rounded))
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
                        .font(.system(size: 68, weight: .black, design: .rounded))
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
                                .font(.system(size: 68, weight: .black, design: .rounded))
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
                
                Spacer()

                // Song selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("SELECT SONG")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .padding(.top, 6)

                    ForEach(SongMetadata.library) { song in
                        Button(action: {
                            selectedSong = song
                        }) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title.uppercased())
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    Text(song.artist)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("BPM \(Int(song.bpm))")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text("\(song.lanes)-LANE")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                if selectedSong.id == song.id {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(song.accent)
                                        .font(.system(size: 22, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: song.primaryColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ).opacity(0.5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedSong.id == song.id ? song.accent : Color.white.opacity(0.2), lineWidth: 2)
                            )
                            .cornerRadius(14)
                            .shadow(color: song.accent.opacity(0.35), radius: 16, y: 6)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 10)
                
                // Difficulty selection
                if showDifficultyMenu {
                    HStack(spacing: 8) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            Button(action: {
                                selectedDifficulty = difficulty
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showDifficultyMenu = false
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(difficulty.rawValue.prefix(1))
                                        .font(.system(size: 20, weight: .black, design: .rounded))
                                    Text(difficulty.rawValue)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(selectedDifficulty == difficulty ? .yellow : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedDifficulty == difficulty ?
                                    Color.cyan.opacity(0.4) : Color.white.opacity(0.15)
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedDifficulty == difficulty ? Color.yellow : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                }
                
                // Play button
                VStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            showDifficultyMenu.toggle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: showDifficultyMenu ? "chevron.up" : "chevron.down")
                                .font(.system(size: 18, weight: .bold))
                            Text(showDifficultyMenu ? "HIDE" : "DIFFICULTY: \(selectedDifficulty.rawValue.uppercased())")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.cyan.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            isPlaying = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                            Text("START GAME")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .purple.opacity(0.6), radius: 20, y: 10)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    }
                }
                .padding(.bottom, 60)
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
