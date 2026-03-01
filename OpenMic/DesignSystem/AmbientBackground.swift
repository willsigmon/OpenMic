import SwiftUI

// MARK: - Ambient Background

/// Animated dark background with subtle floating orbs for the Midnight Dashboard feel
struct AmbientBackground: View {
    let state: VoiceSessionState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0
    @State private var orb1Offset: CGSize = .zero
    @State private var orb2Offset: CGSize = .zero
    @State private var orb3Offset: CGSize = .zero

    private var stateColor: Color {
        switch state {
        case .idle: OpenMicTheme.Colors.accentGradientStart
        case .listening: OpenMicTheme.Colors.listening
        case .processing: OpenMicTheme.Colors.processing
        case .speaking: OpenMicTheme.Colors.speaking
        case .error: OpenMicTheme.Colors.error
        }
    }

    private var orbIntensity: CGFloat {
        if colorScheme == .light {
            return state.isActive ? 0.22 : 0.12
        } else {
            return state.isActive ? 0.15 : 0.06
        }
    }

    private var baseGradient: LinearGradient {
        if colorScheme == .light {
            return LinearGradient(
                colors: [
                    Color(hex: 0xF4F8FF),
                    Color(hex: 0xF8F4FF),
                    Color(hex: 0xF2FBFF)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    OpenMicTheme.Colors.background,
                    OpenMicTheme.Colors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base
                Rectangle()
                    .fill(baseGradient)
                    .ignoresSafeArea()

                // Orb 1 - top left, large, slow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                stateColor.opacity(orbIntensity),
                                stateColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .offset(
                        x: -geo.size.width * 0.25 + orb1Offset.width,
                        y: -geo.size.height * 0.2 + orb1Offset.height
                    )

                // Orb 2 - bottom right, medium
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                OpenMicTheme.Colors.accentGradientEnd.opacity(orbIntensity * 0.7),
                                OpenMicTheme.Colors.accentGradientEnd.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(
                        x: geo.size.width * 0.3 + orb2Offset.width,
                        y: geo.size.height * 0.25 + orb2Offset.height
                    )

                // Orb 3 - center bottom, accent
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                stateColor.opacity(orbIntensity * 0.5),
                                stateColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.35
                        )
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(
                        x: orb3Offset.width,
                        y: geo.size.height * 0.35 + orb3Offset.height
                    )

                // Noise overlay for texture
                Rectangle()
                    .fill(
                        colorScheme == .light
                            ? Color.white.opacity(0.12)
                            : OpenMicTheme.Colors.background.opacity(0.3)
                    )
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if !reduceMotion {
                startOrbAnimation()
            }
        }
        .onChange(of: state) { _, _ in
            // Smooth transition of orb colors handled by animation
        }
        .animation(.easeInOut(duration: 1.0), value: state)
    }

    private func startOrbAnimation() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            orb1Offset = CGSize(width: 30, height: 20)
        }
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(1)) {
            orb2Offset = CGSize(width: -25, height: -15)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(2)) {
            orb3Offset = CGSize(width: 15, height: -25)
        }
    }
}

// MARK: - Floating Particles

struct FloatingParticles: View {
    let count: Int
    let isActive: Bool
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: CGFloat
        var speed: CGFloat
    }

    init(count: Int = 15, isActive: Bool = true, color: Color = OpenMicTheme.Colors.accentGradientStart) {
        self.count = count
        self.isActive = isActive
        self.color = color
    }

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, size in
                        for particle in particles {
                            let rect = CGRect(
                                x: particle.x * size.width,
                                y: particle.y * size.height,
                                width: particle.size,
                                height: particle.size
                            )
                            context.opacity = isActive ? particle.opacity : particle.opacity * 0.3
                            context.fill(
                                Circle().path(in: rect),
                                with: .color(color)
                            )
                        }
                    }
                }
                .onAppear {
                    initializeParticles()
                }
                .task {
                    await animateParticles()
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func initializeParticles() {
        particles = (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1.5...3.5),
                opacity: Double.random(in: 0.1...0.4),
                speed: CGFloat.random(in: 0.0003...0.001)
            )
        }
    }

    private func animateParticles() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(33))
            for i in particles.indices {
                particles[i].y -= particles[i].speed
                particles[i].x += CGFloat.random(in: -0.0005...0.0005)
                if particles[i].y < -0.05 {
                    particles[i].y = 1.05
                    particles[i].x = CGFloat.random(in: 0...1)
                }
            }
        }
    }
}
