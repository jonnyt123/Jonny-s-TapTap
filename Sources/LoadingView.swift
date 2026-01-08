import SwiftUI

struct LoadingView: View {
    @State private var loadingProgress: Double = 0.0
    @State private var isLoading = true
    @Binding var isComplete: Bool
    
    var body: some View {
        ZStack {
            // Background image
            if let image = UIImage(named: "LaunchScreen.png") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(Color.black)
                    .ignoresSafeArea()
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }
            
            // Loading bar at bottom
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.2))
                            .frame(width: 300, height: 6)
                        
                        // Progress bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.4, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 300 * loadingProgress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                    }
                    
                    // Percentage text
                    Text("\(Int(loadingProgress * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            loadResources()
        }
    }
    
    private func loadResources() {
        Task {
            // Simulate realistic loading with variable speeds
            let loadingSteps: [(progress: Double, delay: UInt64)] = [
                (0.05, 150_000_000),   // Fast initial load
                (0.12, 200_000_000),   // Slower
                (0.18, 100_000_000),   // Quick burst
                (0.25, 300_000_000),   // Slow down
                (0.35, 250_000_000),   // Medium
                (0.42, 150_000_000),   // Speed up
                (0.55, 400_000_000),   // Big slow chunk
                (0.63, 180_000_000),   // Medium
                (0.70, 220_000_000),   // Slow
                (0.78, 150_000_000),   // Speed up
                (0.85, 200_000_000),   // Medium
                (0.91, 100_000_000),   // Quick
                (0.96, 180_000_000),   // Almost done
                (1.00, 250_000_000),   // Final push
            ]
            
            for step in loadingSteps {
                try? await Task.sleep(nanoseconds: step.delay)
                await MainActor.run {
                    loadingProgress = step.progress
                }
            }
            
            // Small delay before transitioning
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                isComplete = true
            }
        }
    }
}
