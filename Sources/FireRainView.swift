import SwiftUI

struct FireRainView: View {
    @State private var particles: [FireParticle] = []
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [particle.color, particle.color.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: particle.size / 2
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 1)
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
        particles = (0..<25).map { _ in
            FireParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -size.height...0),
                speed: CGFloat.random(in: 2...5),
                size: CGFloat.random(in: 4...12),
                color: [.red, .orange, .yellow].randomElement()!
            )
        }
    }
    
    private func updateParticles(in size: CGSize) {
        for index in particles.indices {
            particles[index].y += particles[index].speed
            
            // Reset particle to top when it goes off screen
            if particles[index].y > size.height + 20 {
                particles[index].y = -20
                particles[index].x = CGFloat.random(in: 0...size.width)
                particles[index].speed = CGFloat.random(in: 2...5)
                particles[index].size = CGFloat.random(in: 4...12)
                particles[index].color = [.red, .orange, .yellow].randomElement()!
            }
        }
    }
}

struct FireParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var size: CGFloat
    var color: Color
}
