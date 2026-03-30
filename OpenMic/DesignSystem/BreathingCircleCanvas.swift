import SwiftUI

// MARK: - BreathingCircleCanvas (OpenMic)
//
// Three-layer ambient breathing indicator ported from LeavnAndroid `GuidedSessionScreen.BreathingCircle`.
// Used in OpenMic as an "idle / ready" ambient indicator behind MicButton.
//
// Layers:
//   1. Outer glow  — RadialGradient fill, radius * 1.3 * breathScale, opacity 0.3
//   2. Middle ring — stroked circle, lineWidth 2, radius * breathScale, opacity 0.7
//   3. Inner fill  — solid circle, radius * 0.6 * breathScale, opacity 0.5
//
// Animation: EaseInOutSine approximated as timingCurve(0.37, 0, 0.63, 1) at 4 s,
//            repeating with autoreverses — scale range 0.85…1.15.
// Reduce-motion: freezes at scale 1.0, no repeating animation.
// isActive: stops the animation to conserve battery when voice session is not idle.

/// Ambient three-concentric-circle breathing visualiser drawn in a SwiftUI `Canvas`.
///
/// Default color is `OpenMicTheme.Colors.accent` (cyan). Pass any `Color` to reuse
/// across different session states.
///
/// - Parameters:
///   - color: Tint for all three layers. Defaults to `OpenMicTheme.Colors.accent`.
///   - isActive: When `false` the animation freezes at neutral scale.
struct BreathingCircleCanvas: View {
    var color: Color
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathScale: Double = 1.0

    init(color: Color = OpenMicTheme.Colors.accent, isActive: Bool = true) {
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) / 2

            // --- Layer 1: Outer glow (RadialGradient fill) ---
            let glowRadius = baseRadius * 1.3 * breathScale
            let glowGradient = Gradient(stops: [
                .init(color: color.opacity(0.3), location: 0),
                .init(color: color.opacity(0.0), location: 1)
            ])
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - glowRadius,
                    y: center.y - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                )),
                with: .radialGradient(
                    glowGradient,
                    center: center,
                    startRadius: 0,
                    endRadius: glowRadius
                )
            )

            // --- Layer 2: Middle ring (stroked) ---
            let ringRadius = baseRadius * breathScale
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: center.x - ringRadius,
                    y: center.y - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )),
                with: .color(color.opacity(0.7)),
                style: StrokeStyle(lineWidth: 2)
            )

            // --- Layer 3: Inner fill ---
            let innerRadius = baseRadius * 0.6 * breathScale
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - innerRadius,
                    y: center.y - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                )),
                with: .color(color.opacity(0.5))
            )
        }
        .drawingGroup()
        .onChange(of: isActive) { _, active in
            updateAnimation(active: active)
        }
        .onChange(of: reduceMotion) { _, reduced in
            // If the user enables Reduce Motion mid-session, stop the animation immediately.
            if reduced {
                stopBreathing()
            } else {
                updateAnimation(active: isActive)
            }
        }
        .onAppear {
            updateAnimation(active: isActive)
        }
    }

    // MARK: - Animation Control

    private func updateAnimation(active: Bool) {
        if active && !reduceMotion {
            startBreathing()
        } else {
            stopBreathing()
        }
    }

    private func startBreathing() {
        breathScale = 0.85
        withAnimation(
            .timingCurve(0.37, 0, 0.63, 1, duration: 4.0)
                .repeatForever(autoreverses: true)
        ) {
            breathScale = 1.15
        }
    }

    private func stopBreathing() {
        withAnimation(OpenMicTheme.Animation.fast) {
            breathScale = 1.0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BreathingCircleCanvas_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: 0x0A0A0F).ignoresSafeArea()
            BreathingCircleCanvas(color: OpenMicTheme.Colors.accent, isActive: true)
                .frame(width: 200, height: 200)
        }
        .previewDisplayName("Idle – Cyan")

        ZStack {
            Color(hex: 0x0A0A0F).ignoresSafeArea()
            BreathingCircleCanvas(color: OpenMicTheme.Colors.listening, isActive: true)
                .frame(width: 200, height: 200)
        }
        .previewDisplayName("Listening – Green")
    }
}
#endif
