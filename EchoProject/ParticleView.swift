import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var velocityX: CGFloat
    var velocityY: CGFloat
}

struct ParticleView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(x: particle.x, y: particle.y, width: particle.size, height: particle.size)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.red.opacity(particle.opacity))
                    )
                }
            }
            .onAppear {
                initializeParticles()
            }
            .onChange(of: timeline.date) { _ in
                updateParticles()
            }
        }
    }
    
    private func initializeParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        particles = (0..<30).map { _ in
            Particle(
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 6...12),
                opacity: Double.random(in: 0.4...0.7),
                velocityX: CGFloat.random(in: -0.5...0.5),
                velocityY: CGFloat.random(in: -0.8...(-0.2))
            )
        }
    }
    
    private func updateParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for i in particles.indices {
            particles[i].x += particles[i].velocityX
            particles[i].y += particles[i].velocityY
            
            // Wrap around screen edges
            if particles[i].x < -10 {
                particles[i].x = screenWidth + 10
            } else if particles[i].x > screenWidth + 10 {
                particles[i].x = -10
            }
            
            if particles[i].y < -10 {
                particles[i].y = screenHeight + 10
            } else if particles[i].y > screenHeight + 10 {
                particles[i].y = -10
            }
        }
    }
}
