import SwiftUI

// MARK: - Primary Button Style

struct OpenMicPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OpenMicTheme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                    .fill(OpenMicTheme.Gradients.accent)
                    .opacity(isEnabled ? 1.0 : 0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                    .strokeBorder(
                        OpenMicTheme.Colors.surfaceBorder.opacity(0.75),
                        lineWidth: 0.75
                    )
            )
            .shadow(
                color: OpenMicTheme.Colors.glowCyan,
                radius: configuration.isPressed ? 4 : 12
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(OpenMicTheme.Animation.micro, value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct OpenMicSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OpenMicTheme.Typography.headline)
            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                    .fill(OpenMicTheme.Colors.surfaceGlass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                    .strokeBorder(
                        OpenMicTheme.Colors.accentGradientStart.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(OpenMicTheme.Animation.micro, value: configuration.isPressed)
    }
}

// MARK: - Ghost Button Style

struct OpenMicGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OpenMicTheme.Typography.callout)
            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
            .padding(.vertical, OpenMicTheme.Spacing.xs)
            .padding(.horizontal, OpenMicTheme.Spacing.md)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(OpenMicTheme.Animation.micro, value: configuration.isPressed)
    }
}

// MARK: - Action Pill Button Style

enum OpenMicActionPillTone: Sendable {
    case danger
    case accent
}

struct OpenMicActionPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let tone: OpenMicActionPillTone

    private var foreground: Color {
        switch tone {
        case .danger: .white
        case .accent: OpenMicTheme.Colors.accentGradientStart
        }
    }

    private var fillGradient: LinearGradient {
        switch tone {
        case .danger:
            LinearGradient(
                colors: [
                    OpenMicTheme.Colors.error.opacity(0.65),
                    OpenMicTheme.Colors.error.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accent:
            LinearGradient(
                colors: [
                    OpenMicTheme.Colors.surfaceGlass,
                    OpenMicTheme.Colors.surfaceSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var border: Color {
        switch tone {
        case .danger: OpenMicTheme.Colors.error.opacity(0.35)
        case .accent: OpenMicTheme.Colors.accentGradientStart.opacity(0.35)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, OpenMicTheme.Spacing.sm)
            .padding(.vertical, OpenMicTheme.Spacing.xxs + 1)
            .background(
                Capsule()
                    .fill(fillGradient)
                    .overlay(
                        Capsule().strokeBorder(border, lineWidth: 0.7)
                    )
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(OpenMicTheme.Animation.micro, value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == OpenMicPrimaryButtonStyle {
    static var openMicPrimary: OpenMicPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == OpenMicSecondaryButtonStyle {
    static var openMicSecondary: OpenMicSecondaryButtonStyle { .init() }
}

extension ButtonStyle where Self == OpenMicGhostButtonStyle {
    static var openMicGhost: OpenMicGhostButtonStyle { .init() }
}

extension ButtonStyle where Self == OpenMicActionPillButtonStyle {
    static func openMicActionPill(
        tone: OpenMicActionPillTone
    ) -> OpenMicActionPillButtonStyle {
        .init(tone: tone)
    }
}
