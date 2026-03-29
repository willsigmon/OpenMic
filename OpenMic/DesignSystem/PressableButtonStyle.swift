import SwiftUI

// MARK: - Pressable Button Style

/// A standalone button style for non-system elements (cards, tiles, icon buttons)
/// that only need the press-scale mechanic without OpenMic's gradient/border chrome.
///
/// Uses `OpenMicTheme.Animation.springy` to match the rest of the design system.
/// For full-width CTA buttons use `OpenMicPrimaryButtonStyle` instead.
struct PressableButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(OpenMicTheme.Animation.springy, value: configuration.isPressed)
    }
}

// MARK: - Bouncy Variant

/// More dramatic press effect — 0.94 scale with extra bounce.
/// Use on large cards or hero tiles where the spring snap should be perceptible.
struct PressableBouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(OpenMicTheme.Animation.bouncy, value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == PressableButtonStyle {
    /// Subtle 0.96 spring press effect. Matches the `springy` animation token.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    /// Pressable with a custom scale value.
    static func pressable(scale: CGFloat) -> PressableButtonStyle {
        PressableButtonStyle(scaleAmount: scale)
    }
}

extension ButtonStyle where Self == PressableBouncyButtonStyle {
    /// 0.94 scale with higher bounce amplitude. Use on large interactive surfaces.
    static var pressableBouncy: PressableBouncyButtonStyle { PressableBouncyButtonStyle() }
}
