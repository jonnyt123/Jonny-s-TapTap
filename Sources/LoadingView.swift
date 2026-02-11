import SwiftUI

struct LoadingView: View {
    @State private var loadingProgress: Double = 0.0
    @State private var isLoading = true
    @Binding var isComplete: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = UIImage(named: "LaunchScreen.png") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(Color.black)
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.2))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.4, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min((geo.size.width - 48).safeFinite, 320)) * loadingProgress)
                                .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                        }
                        .frame(width: max(0, min((geo.size.width - 48).safeFinite, 320)), height: 6)
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 50)
                }
            }
        }
        .ignoresSafeArea()
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
