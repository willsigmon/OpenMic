import SwiftUI

// MARK: - Gradient Icon Container

/// Premium icon with gradient background, glow, and optional animation
struct GradientIcon: View {
    let systemName: String
    let gradient: LinearGradient
    let size: CGFloat
    let iconSize: CGFloat
    let glowColor: Color
    let isAnimated: Bool

    @State private var isBreathing = false

    init(
        systemName: String,
        gradient: LinearGradient = OpenMicTheme.Gradients.accent,
        size: CGFloat = 56,
        iconSize: CGFloat = 24,
        glowColor: Color = OpenMicTheme.Colors.glowCyan,
        isAnimated: Bool = false
    ) {
        self.systemName = systemName
        self.gradient = gradient
        self.size = size
        self.iconSize = iconSize
        self.glowColor = glowColor
        self.isAnimated = isAnimated
    }

    var body: some View {
        ZStack {
            // Glow backdrop
            Circle()
                .fill(glowColor)
                .frame(width: size * 1.2, height: size * 1.2)
                .blur(radius: size * 0.3)
                .opacity(isAnimated && isBreathing ? 0.6 : 0.3)

            // Gradient circle
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )

            // Icon
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .scaleEffect(isAnimated && isBreathing ? 1.05 : 1.0)
        .onAppear {
            if isAnimated {
                withAnimation(OpenMicTheme.Animation.breathe) {
                    isBreathing = true
                }
            }
        }
    }
}

// MARK: - Layered Feature Icon

/// Multi-layer icon with accent shape overlay (ring, sparkle, etc.)
struct LayeredFeatureIcon: View {
    let systemName: String
    let color: Color
    let accentShape: AccentShape

    enum AccentShape {
        case ring
        case sparkle
        case rays
        case dots
        case none
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                .fill(color.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )

            // Accent shape behind icon
            accentOverlay
                .foregroundStyle(color.opacity(0.15))

            // Main icon
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(width: 48, height: 48)
    }

    @ViewBuilder
    private var accentOverlay: some View {
        switch accentShape {
        case .ring:
            Circle()
                .strokeBorder(lineWidth: 1.5)
                .frame(width: 36, height: 36)
        case .sparkle:
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .offset(x: 14, y: -14)
        case .rays:
            Image(systemName: "rays")
                .font(.system(size: 30))
                .opacity(0.3)
        case .dots:
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .frame(width: 3, height: 3)
                }
            }
            .offset(y: 16)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Provider Logo

/// Styled provider icon using official brand logos with a tinted background circle
struct ProviderIcon: View {
    let provider: AIProviderType
    let size: CGFloat

    init(provider: AIProviderType, size: CGFloat = 32) {
        self.provider = provider
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(OpenMicTheme.Colors.providerColor(provider).opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(
                            OpenMicTheme.Colors.providerColor(provider).opacity(0.3),
                            lineWidth: 0.5
                        )
                )

            BrandLogo(provider, size: size * 0.75, tint: OpenMicTheme.Colors.providerColor(provider))
        }
    }
}

// MARK: - Animated Voice State Icon

struct VoiceStateIcon: View {
    let state: VoiceSessionState

    @State private var rotation: Double = 0
    @State private var tilt: Bool = false

    var body: some View {
        ZStack {
            switch state {
            case .idle:
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            case .listening:
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Colors.listening)
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .rotationEffect(.degrees(tilt ? 3 : -3))
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: tilt
                    )
                    .onAppear { tilt = true }

            case .processing:
                Image(systemName: "circle.dotted")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Colors.processing)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

            case .speaking:
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Colors.speaking)
                    .symbolEffect(.variableColor.iterative, isActive: true)

            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OpenMicTheme.Colors.error)
            }
        }
    }
}
