import SwiftUI

// MARK: - SparkleModifier

/// 5-radial-particle burst on a boolean trigger edge (false → true).
/// Ported from AiSL's SparkleModifier; colors adapted to OpenMic's palette.
struct SparkleModifier: ViewModifier {
    let isActive: Bool

    @State private var scale: CGFloat = 1.0
    @State private var sparkles: [SparkleParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay {
                ForEach(sparkles) { sparkle in
                    Circle()
                        .fill(sparkle.color)
                        .frame(width: sparkle.size, height: sparkle.size)
                        .offset(sparkle.offset)
                        .opacity(sparkle.opacity)
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: isActive) { _, active in
                guard !reduceMotion else { return }
                if active { trigger() }
            }
    }

    // MARK: - Trigger

    private func trigger() {
        // Pop scale
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            scale = 1.15
        }

        sparkles = (0..<5).map { i in
            let angle = Double(i) / 5.0 * .pi * 2
            let distance: CGFloat = 24
            return SparkleParticle(
                id: UUID(),
                offset: CGSize(
                    width: cos(angle) * distance,
                    height: sin(angle) * distance
                ),
                color: Self.palette[i % Self.palette.count],
                size: CGFloat.random(in: 4...8),
                opacity: 1.0
            )
        }

        // Restore scale
        withAnimation(.easeOut(duration: 0.2).delay(0.15)) {
            scale = 1.0
        }

        // Expand and fade
        withAnimation(.easeOut(duration: 0.4)) {
            sparkles = sparkles.map { particle in
                SparkleParticle(
                    id: particle.id,
                    offset: CGSize(
                        width: particle.offset.width * 2.2,
                        height: particle.offset.height * 2.2
                    ),
                    color: particle.color,
                    size: particle.size,
                    opacity: 0
                )
            }
        }

        // Cleanup
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            sparkles = []
        }
    }

    // MARK: - Palette

    private static let palette: [Color] = [
        OpenMicTheme.Colors.accentGradientStart,              // cyan
        Color(hex: 0xFFD700),                                 // gold
        OpenMicTheme.Colors.accentGradientEnd,                // blue
        OpenMicTheme.Colors.accentGradientStart.opacity(0.7), // soft cyan
        Color(hex: 0xFFD700, opacity: 0.7),                   // soft gold
    ]
}

// MARK: - SparkleParticle

private struct SparkleParticle: Identifiable {
    let id: UUID
    var offset: CGSize
    var color: Color
    var size: CGFloat
    var opacity: Double
}

// MARK: - View Extension

extension View {
    /// Fires a 5-radial sparkle burst when `active` transitions to `true`.
    func sparkle(when active: Bool) -> some View {
        modifier(SparkleModifier(isActive: active))
    }
}
