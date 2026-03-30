import SwiftUI

// MARK: - CelebrationParticleView

/// Full-screen particle celebration using TimelineView + Canvas.
/// Zero SwiftUI view overhead per particle — all drawing is deferred to Canvas.
/// Use `.allowsHitTesting(false)` and `.accessibilityHidden(true)` at the call site,
/// or rely on the modifiers already applied inside this view.
struct CelebrationParticleView: View {
    /// 20 for small wins, 50 for big milestones.
    let particleCount: Int

    @State private var particles: [CelebrationParticle] = []
    @State private var startDate: Date = .distantFuture
    @State private var isActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(particleCount: Int = 40) {
        self.particleCount = particleCount
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isActive)) { timeline in
            Canvas { context, size in
                guard isActive else { return }
                let elapsed = timeline.date.timeIntervalSince(startDate)

                for particle in particles {
                    let t = elapsed / particle.duration
                    guard t >= 0, t <= 1 else { continue }

                    let gravity = 600.0 * t * t
                    let x = particle.startX * size.width + particle.driftX * t * size.width
                    let y = particle.startY * size.height
                        + particle.velocityY * t * size.height
                        + gravity * t

                    let opacity = 1.0 - max(0, (t - 0.6) / 0.4)
                    let rotation = Angle.degrees(particle.spin * t * 360)
                    let scale = particle.scale * (1 - t * 0.3)

                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)
                    ctx.opacity = opacity

                    let rect = CGRect(
                        x: -4 * scale,
                        y: -4 * scale,
                        width: 8 * scale,
                        height: 8 * scale
                    )

                    switch particle.type {
                    case .confetti:
                        ctx.fill(Path(rect), with: .color(particle.color))

                    case .sparkle:
                        ctx.fill(
                            fourPointStar(in: rect),
                            with: .color(particle.color)
                        )

                    case .soundWave:
                        let arc = arcPath(in: rect)
                        ctx.stroke(arc, with: .color(particle.color), lineWidth: 1.5 * scale)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            launch()
        }
    }

    // MARK: - Launch

    private func launch() {
        let now = Date()
        startDate = now
        particles = (0..<particleCount).map { _ in CelebrationParticle(startTime: now) }
        isActive = true

        let maxDuration = particles.map(\.duration).max() ?? 2.5
        Task {
            try? await Task.sleep(for: .seconds(maxDuration + 0.1))
            isActive = false
        }
    }

    // MARK: - Shape Helpers

    private func fourPointStar(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let outer = rect.width / 2
        let inner = outer * 0.4
        let points = 4

        for i in 0..<points {
            let outerAngle = Double(i) * (.pi * 2 / Double(points)) - .pi / 2
            let innerAngle = outerAngle + .pi / Double(points)

            let outerX = cx + cos(outerAngle) * outer
            let outerY = cy + sin(outerAngle) * outer
            let innerX = cx + cos(innerAngle) * inner
            let innerY = cy + sin(innerAngle) * inner

            if i == 0 {
                path.move(to: CGPoint(x: outerX, y: outerY))
            } else {
                path.addLine(to: CGPoint(x: outerX, y: outerY))
            }
            path.addLine(to: CGPoint(x: innerX, y: innerY))
        }
        path.closeSubpath()
        return path
    }

    private func arcPath(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: rect.width / 2,
                startAngle: .degrees(-60),
                endAngle: .degrees(60),
                clockwise: false
            )
        }
    }
}

// MARK: - CelebrationParticle

private enum ParticleType: CaseIterable {
    case confetti
    case sparkle
    case soundWave
}

private struct CelebrationParticle {
    let startTime: Date
    let startX: Double
    let startY: Double
    let velocityY: Double
    let driftX: Double
    let duration: Double
    let spin: Double
    let scale: Double
    let color: Color
    let type: ParticleType

    init(startTime: Date) {
        self.startTime = startTime
        self.startX = Double.random(in: 0.1...0.9)
        self.startY = Double.random(in: -0.1...0.05)
        self.velocityY = Double.random(in: -0.3...0.1)
        self.driftX = Double.random(in: -0.15...0.15)
        self.duration = Double.random(in: 1.8...2.5)
        self.spin = Double.random(in: -2...2)
        self.scale = Double.random(in: 0.8...1.5)
        self.color = Self.palette.randomElement() ?? OpenMicTheme.Colors.accentGradientStart
        self.type = ParticleType.allCases.randomElement() ?? .confetti
    }

    /// OpenMic palette: accent blue, provider-adjacent cyan, gold, success green, provider purples.
    private static let palette: [Color] = [
        OpenMicTheme.Colors.accentGradientStart,        // cyan
        OpenMicTheme.Colors.accentGradientEnd,          // blue
        Color(hex: 0xFFD700),                           // gold
        OpenMicTheme.Colors.success,                    // green
        Color(hex: 0xD4A574),                           // Anthropic warm sand
        Color(hex: 0x7C4DFF),                           // purple
        OpenMicTheme.Colors.accentGradientStart.opacity(0.7),
        Color(hex: 0xFFD700, opacity: 0.7),
    ]
}

// MARK: - Particle Count Constants

enum CelebrationSize {
    /// Small wins: first message, provider switch.
    static let small = 20
    /// Milestone wins: 10th, 50th, 100th message.
    static let large = 50
}
