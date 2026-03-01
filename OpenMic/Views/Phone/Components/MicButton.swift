import SwiftUI

struct MicButton: View {
    let state: VoiceSessionState
    let action: () -> Void
    var isDragging: Bool = false

    private let size: CGFloat = 70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring1Opacity: CGFloat = 0.5
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring2Opacity: CGFloat = 0.4
    @State private var ring3Scale: CGFloat = 1.0
    @State private var ring3Opacity: CGFloat = 0.3

    private var isActive: Bool { state.isActive }

    private var stateGradient: LinearGradient {
        switch state {
        case .idle: OpenMicTheme.Gradients.accent
        case .listening: OpenMicTheme.Gradients.listening
        case .processing: OpenMicTheme.Gradients.processing
        case .speaking: OpenMicTheme.Gradients.speaking
        case .error: OpenMicTheme.Gradients.error
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle: OpenMicTheme.Colors.accentGradientStart
        case .listening: OpenMicTheme.Colors.listening
        case .processing: OpenMicTheme.Colors.processing
        case .speaking: OpenMicTheme.Colors.speaking
        case .error: OpenMicTheme.Colors.error
        }
    }

    private var iconName: String {
        switch state {
        case .idle: "mic.fill"
        case .listening: "waveform"
        case .processing: "ellipsis"
        case .speaking: "speaker.wave.2.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing rings (visible when active)
                if isActive {
                    pulsingRings
                }

                // Outer glow
                Circle()
                    .fill(stateColor.opacity(0.08))
                    .frame(width: size + 32, height: size + 32)
                    .blur(radius: 8)
                    .opacity(breathe ? 0.8 : 0.4)

                // Glass ring border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: size + 8, height: size + 8)

                // Main button circle
                Circle()
                    .fill(stateGradient)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(color: stateColor.opacity(0.4), radius: isActive ? 20 : 10)

                // Inner highlight (glass effect)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: size - 2, height: size - 2)
                    .clipShape(
                        Circle().offset(y: -size * 0.15)
                    )

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .symbolEffect(.bounce, value: state)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isDragging ? 1.15 : (isActive && breathe && !reduceMotion ? 1.04 : 1.0))
        .opacity(1.0)
        .shadow(color: stateColor.opacity(isDragging ? 0.7 : 0), radius: isDragging ? 30 : 0)
        .shadow(color: .black.opacity(isDragging ? 0.4 : 0), radius: isDragging ? 12 : 0, y: isDragging ? 8 : 0)
        .sensoryFeedback(.impact(weight: .medium), trigger: state)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isDragging)
        .animation(reduceMotion ? nil : OpenMicTheme.Animation.breathe, value: breathe)
        .animation(OpenMicTheme.Animation.springy, value: state)
        .onAppear {
            if !reduceMotion {
                breathe = true
            }
        }
        .accessibilityLabel(
            isActive ? "Stop conversation" : "Start conversation"
        )
        .accessibilityHint(
            isActive ? "Double-tap to stop" : "Double-tap to begin talking"
        )
    }

    @ViewBuilder
    private var pulsingRings: some View {
        ZStack {
            Circle()
                .strokeBorder(stateColor.opacity(ring1Opacity), lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(ring1Scale)

            Circle()
                .strokeBorder(stateColor.opacity(ring2Opacity), lineWidth: 1.0)
                .frame(width: size, height: size)
                .scaleEffect(ring2Scale)

            Circle()
                .strokeBorder(stateColor.opacity(ring3Opacity), lineWidth: 0.5)
                .frame(width: size, height: size)
                .scaleEffect(ring3Scale)
        }
        .onAppear { startPulsingAnimation() }
        .onChange(of: isActive) { _, active in
            if active { startPulsingAnimation() }
        }
    }

    private func startPulsingAnimation() {
        // Ring 1 - fast
        ring1Scale = 1.0
        ring1Opacity = 0.5
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            ring1Scale = 2.0
            ring1Opacity = 0
        }

        // Ring 2 - medium, delayed
        ring2Scale = 1.0
        ring2Opacity = 0.4
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.5)) {
            ring2Scale = 2.2
            ring2Opacity = 0
        }

        // Ring 3 - slow, more delayed
        ring3Scale = 1.0
        ring3Opacity = 0.3
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(1.0)) {
            ring3Scale = 2.5
            ring3Opacity = 0
        }
    }
}
