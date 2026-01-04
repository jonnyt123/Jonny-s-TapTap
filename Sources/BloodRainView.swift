import SwiftUI

struct BloodRainView: View {
    @State private var particles: [BloodParticle] = []
    let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    RoundedRectangle(cornerRadius: particle.size * 0.3)
                        .fill(particle.color)
                        .frame(width: particle.size * 0.6, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
            }
            .onReceive(timer) { _ in
                updateParticles(in: geometry.size)
            }
            .onAppear {
                initializeParticles(in: geometry.size)
            }
        }
        .ignoresSafeArea()
    }
    
    private func initializeParticles(in size: CGSize) {
        particles = (0..<40).map { _ in
            let bloodRed = Color(red: 0.6, green: 0.0, blue: 0.0)
            let darkRed = Color(red: 0.4, green: 0.0, blue: 0.0)
            return BloodParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -size.height...0),
                speed: CGFloat.random(in: 3...6),
                size: CGFloat.random(in: 3...8),
                color: [bloodRed, darkRed].randomElement()!,
                opacity: Double.random(in: 0.5...0.9)
            )
        }
    }
    
    private func updateParticles(in size: CGSize) {
        for index in particles.indices {
            particles[index].y += particles[index].speed
            // Slight horizontal drift
            particles[index].x += CGFloat.random(in: -0.5...0.5)
            // Fade as it falls
            particles[index].opacity = max(0.2, particles[index].opacity - 0.01)
            
            // Reset particle to top when it goes off screen
            if particles[index].y > size.height + 20 {
                let bloodRed = Color(red: 0.6, green: 0.0, blue: 0.0)
                let darkRed = Color(red: 0.4, green: 0.0, blue: 0.0)
                particles[index].y = -20
                particles[index].x = CGFloat.random(in: 0...size.width)
                particles[index].speed = CGFloat.random(in: 3...6)
                particles[index].size = CGFloat.random(in: 3...8)
                particles[index].color = [bloodRed, darkRed].randomElement()!
                particles[index].opacity = Double.random(in: 0.5...0.9)
            }
        }
    }
}

struct BloodParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
