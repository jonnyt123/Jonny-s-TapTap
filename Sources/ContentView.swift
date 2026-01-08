import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var scene: GameScene?
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var selectedSong: SongMetadata = .default
    @State private var availableDifficulties: Set<Difficulty> = Set(Difficulty.allCases)
    
    // Health bar draggable position
    @AppStorage("healthBarOffsetX") private var healthBarOffsetX: Double = 0
    @AppStorage("healthBarOffsetY") private var healthBarOffsetY: Double = 60

    var body: some View {
        ZStack {
            if !isPlaying {
                MainMenuView(gameState: gameState, isPlaying: $isPlaying, selectedDifficulty: $selectedDifficulty, selectedSong: $selectedSong, availableDifficulties: availableDifficulties)
                    .transition(.opacity)
            } else {
                gameView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .onAppear {
            gameState.loadProgress()
            gameState.loadProgressCloud()
            gameState.setSong(selectedSong)
            gameState.setDifficulty(selectedDifficulty)
            refreshAvailability(for: selectedSong)
        }
        .onChange(of: selectedSong) { _, newSong in
            gameState.setSong(newSong)
            refreshAvailability(for: newSong)
            if !availableDifficulties.contains(selectedDifficulty) {
                selectedDifficulty = availableDifficulties.first ?? .medium
                gameState.setDifficulty(selectedDifficulty)
            }
            // Extra stop to ensure previous audio is fully halted when switching songs from the menu
            scene?.stop()
            scene = nil
        }
    }
    
    private var gameView: some View {
        ZStack {
            if let scene = scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            } else {
                Color.clear
            }
            
            overlay
            
            // Blood rain effect
            BloodRainView()
                .allowsHitTesting(false)
            
            if isPaused {
                pauseOverlay
            }
            
            // Failure overlay
            if gameState.isFailed {
                failureOverlay
            }
            
            // Results overlay
            if gameState.isCompleted && !gameState.isFailed {
                resultsOverlay
            }
        }
        .onAppear {
            if scene == nil && isPlaying {
                // Reset game state before starting
                gameState.reset()
                let newScene = GameScene()
                newScene.scaleMode = .resizeFill
                newScene.setSong(selectedSong)
                gameState.setSong(selectedSong)
                gameState.setDifficulty(selectedDifficulty)
                newScene.gameState = gameState
                scene = newScene
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scene?.start()
                    scene?.startMusic()
                }
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                // Reset game state before creating fresh scene
                gameState.reset()
                // Create fresh scene when starting game
                let newScene = GameScene()
                newScene.scaleMode = .resizeFill
                newScene.setSong(selectedSong)
                gameState.setSong(selectedSong)
                gameState.setDifficulty(selectedDifficulty)
                newScene.gameState = gameState
                scene = newScene
                
                // Start game after scene is set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scene?.start()
                    scene?.startMusic()
                }
            } else {
                // Clean up scene when exiting
                scene?.stop()
                scene = nil
            }
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .blur(radius: 4)
            
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Text("PAUSED")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: .cyan, radius: 20)
                    
                    Divider()
                        .background(Color.cyan.opacity(0.5))
                }
                
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 18))
                        Text("Tap Coins: \(gameState.tapCoins)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    
                    Button(action: {
                        isPaused = false
                        scene?.resume()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("Resume")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                        .shadow(color: Color.green.opacity(0.6), radius: 10)
                    }
                    
                    Button(action: {
                        scene?.stop()
                        gameState.reset()
                        isPaused = false
                        isPlaying = false
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Exit")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                        .shadow(color: Color.red.opacity(0.6), radius: 10)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
            }
            .padding(40)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private var failureOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("FAILED!")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .shadow(color: .red, radius: 30)
                    .scaleEffect(1.1)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Missed Notes:")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(gameState.missedNotes)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                    }
                    
                    HStack {
                        Text("Final Score:")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(gameState.score)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
                
                Button(action: {
                    scene?.stop()
                    gameState.reset()
                    isPlaying = false
                }) {
                    Label("Return to Menu", systemImage: "house.fill")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                }
                .padding(.horizontal, 40)
            }
            .padding(40)
        }
    }
    
    private var overlay: some View {
        VStack(spacing: 0) {
            // Top bar with glassmorphic effect - compact layout
            HStack(alignment: .center, spacing: 12) {
                // Pause button
                Button(action: {
                    isPaused = true
                    scene?.pause()
                }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                
                // Score - Compact
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(gameState.score)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Tap Coins - Compact
                VStack(alignment: .leading, spacing: 2) {
                    Text("COINS")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow)
                        Text("\(gameState.tapCoins)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                
                // Multiplier - Compact with icon
                VStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 2) {
                        Text("\(gameState.multiplier)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                        Text("×")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
                
                // Combo - Compact with flame
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 3) {
                        Text("\(gameState.combo)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(comboColor)
                        if gameState.combo > 5 {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(comboColor)
                                .font(.system(size: 14))
                        }
                    }
                    Text("COMBO")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Revenge Mode indicator
            if gameState.revengeActive {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("REVENGE MODE ACTIVE!")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
                .shadow(color: .orange.opacity(0.5), radius: 10)
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            } else if gameState.canActivateRevenge() {
                Button(action: {
                    scene?.activateRevengeFromButton()
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("ACTIVATE REVENGE")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cyan.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan, lineWidth: 2)
                            )
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            Spacer()
        }
        .overlay {
            // Draggable vertical health bar
            VStack(spacing: 8) {
                Text("HP")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(width: 20)
                        
                        Capsule()
                            .fill(LinearGradient(
                                colors: healthGradient,
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(width: 20, height: geo.size.height * gameState.health)
                            .animation(.spring(response: 0.3), value: gameState.health)
                    }
                }
                .frame(width: 20, height: 200)
                
                Text("\(Int((1.0 - Double(gameState.missedNotes) / 100.0) * 100))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(8)
            .background(.ultraThinMaterial.opacity(0.3))
            .cornerRadius(12)
            .position(
                x: UIScreen.main.bounds.width - 20 + healthBarOffsetX,
                y: healthBarOffsetY + 140
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        healthBarOffsetX = value.translation.width
                        healthBarOffsetY = value.translation.height + 60
                    }
                    .onEnded { value in
                        // Keep the final position
                        healthBarOffsetX += value.translation.width
                        healthBarOffsetY += value.translation.height
                    }
            )
        }
    }
    
    private var comboColor: Color {
        if gameState.combo > 20 { return .purple }
        if gameState.combo > 10 { return .orange }
        if gameState.combo > 5 { return .yellow }
        return .white
    }
    
    private var healthGradient: [Color] {
        if gameState.health > 0.6 {
            return [.green, .cyan]
        } else if gameState.health > 0.3 {
            return [.yellow, .orange]
        } else {
            return [.red, .pink]
        }
    }
    
    private var judgementColor: Color {
        switch gameState.lastJudgement {
        case .perfect: return .yellow
        case .great: return .green
        case .good: return .cyan
        case .miss: return .red
        }
    }
    
    private var judgementScale: CGFloat {
        gameState.lastJudgement == .perfect ? 1.2 : 1.0
    }

    private var statusText: String {
        switch gameState.lastJudgement {
        case .perfect: return "Perfect"
        case .great: return "Great"
        case .good: return "Good"
        case .miss: return "Miss"
        }
    }
    
    private var resultsOverlay: some View {
        ResultsView(
            gameState: gameState,
            onRestart: {
                scene?.stop()
                scene = nil
                gameState.reset()
                // Create fresh scene for retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let newScene = GameScene()
                    newScene.scaleMode = .resizeFill
                    newScene.setSong(selectedSong)
                    gameState.setSong(selectedSong)
                    gameState.setDifficulty(selectedDifficulty)
                    newScene.gameState = gameState
                    scene = newScene
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scene?.start()
                        scene?.startMusic()
                    }
                }
            },
            onExit: {
                scene?.stop()
                scene = nil
                gameState.reset()
                isPlaying = false
            }
        )
    }

    private func refreshAvailability(for song: SongMetadata) {
        availableDifficulties = ChartLoader.availability(for: song)
        if availableDifficulties.isEmpty {
            availableDifficulties = [.medium]
        }
    }
}

// MARK: - Results View
struct ResultsView: View {
    let gameState: GameState
    let onRestart: () -> Void
    let onExit: () -> Void
    
    @State private var animateGrade = false
    @State private var animateStats = false
    
    private var accuracy: Double {
        guard gameState.totalNotes > 0 else { return 0 }
        return Double(gameState.notesHit) / Double(gameState.totalNotes) * 100
    }
    
    private var grade: String {
        if accuracy >= 95 { return "S" }
        if accuracy >= 90 { return "A" }
        if accuracy >= 80 { return "B" }
        if accuracy >= 70 { return "C" }
        if accuracy >= 60 { return "D" }
        return "F"
    }
    
    private var gradeColor: Color {
        switch grade {
        case "S": return Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        case "A": return Color(red: 0.2, green: 0.8, blue: 0.2)   // Bright green
        case "B": return Color(red: 0.3, green: 0.7, blue: 1.0)   // Sky blue
        case "C": return Color(red: 1.0, green: 0.6, blue: 0.2)   // Orange
        case "D": return Color(red: 1.0, green: 0.3, blue: 0.3)   // Red
        default: return .gray
        }
    }
    
    private var gradeGlow: Color {
        switch grade {
        case "S": return Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6)
        case "A": return Color(red: 0.2, green: 0.8, blue: 0.2).opacity(0.6)
        case "B": return Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.6)
        case "C": return Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.6)
        case "D": return Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.6)
        default: return Color.gray.opacity(0.6)
        }
    }
    
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated background circles
            Circle()
                .fill(gradeGlow)
                .blur(radius: 80)
                .offset(x: -100, y: -100)
                .ignoresSafeArea()
            
            Circle()
                .fill(Color.blue.opacity(0.2))
                .blur(radius: 120)
                .offset(x: 150, y: 200)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: 20)
                
                // Grade Display - Animated
                VStack(spacing: 20) {
                    Text("SONG COMPLETE!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue, gradeColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .cyan, radius: 15)
                    
                    // Grade Circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [gradeColor.opacity(0.3), gradeColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(gradeColor, lineWidth: 3)
                            )
                        
                        Text(grade)
                            .font(.system(size: 100, weight: .black, design: .rounded))
                            .foregroundStyle(gradeColor)
                            .shadow(color: gradeGlow, radius: 20)
                    }
                    .frame(height: 180)
                    .padding(.vertical, 10)
                    .scaleEffect(animateGrade ? 1.0 : 0.8)
                    .opacity(animateGrade ? 1.0 : 0.0)
                }
                .padding(.bottom, 30)
                
                // Stats Card
                VStack(spacing: 20) {
                    // Primary Stats
                    HStack(spacing: 20) {
                        StatCard(
                            label: "Score",
                            value: "\(gameState.score)",
                            icon: "star.fill",
                            color: Color(red: 1.0, green: 0.84, blue: 0.0)
                        )
                        StatCard(
                            label: "Accuracy",
                            value: String(format: "%.1f%%", accuracy),
                            icon: "bullseye",
                            color: .green
                        )
                    }

                    // Coins Earned Banner
                    if gameState.lastCoinsEarned > 0 {
                        HStack(spacing: 10) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.yellow)
                            Text("+\(gameState.lastCoinsEarned) Tap Coins")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                                )
                        )
                    }
                    
                    HStack(spacing: 20) {
                        StatCard(
                            label: "Max Combo",
                            value: "\(gameState.maxCombo)",
                            icon: "flame.fill",
                            color: .red
                        )
                        StatCard(
                            label: "Notes Hit",
                            value: "\(gameState.notesHit)/\(gameState.totalNotes)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                    
                    // Personal Best
                    if gameState.isNewPersonalBest {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.yellow)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NEW PERSONAL BEST!")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.yellow)
                                Text("\(gameState.personalBest)")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(.yellow)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                                )
                        )
                    } else {
                        HStack {
                            Text("Personal Best")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text("\(gameState.personalBest)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .offset(y: animateStats ? 0 : 30)
                .opacity(animateStats ? 1.0 : 0.0)
                
                Spacer()
                
                // Buttons
                HStack(spacing: 16) {
                    Button(action: onRestart) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                            Text("Retry")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.1, green: 0.6, blue: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.2).opacity(0.6), radius: 10)
                    }
                    
                    Button(action: onExit) {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Menu")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.6), radius: 10)
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateGrade = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateStats = true
                }
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

