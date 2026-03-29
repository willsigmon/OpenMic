import SwiftUI

// MARK: - OpenMic Liquid Glass Compat Layer
//
// iOS 26+ path: native .glassEffect() API.
// iOS 18 path: existing GlassCard / GlassBackground from GlassCard.swift.
//
// Audit of all glass/material usage in OpenMic:
//
// Already going through GlassCard / glassBackground():
//   - DesignSystem/GlassCard.swift                — GlassCard struct + GlassBackground modifier
//   - Views/Settings/ProviderCards/ProviderCard.swift          — .ultraThinMaterial fill (not through compat)
//   - Views/Settings/ProviderCards/LocalProviderCard.swift     — .ultraThinMaterial fill (not through compat)
//   - Views/Settings/ProviderCards/SelfHostedProviderCard.swift — .ultraThinMaterial fill (not through compat)
//   - Views/Phone/Components/TopicCategoryCard.swift           — .ultraThinMaterial fill (not through compat)
//   - DesignSystem/EasterEggs.swift                — .background(.ultraThinMaterial, in: Capsule())
//   - Features/Notifications/NotificationPermissionView.swift  — indirect material
//   - Features/Onboarding/SpotlightOverlay/SpotlightOverlay.swift — indirect material
//
// Migration plan (when iOS 26 becomes minimum deployment target):
//
//   1. Delete this file and GlassCard.swift.
//   2. Replace all GlassCard { } usages with content wrapped in .glassEffect(.regular, in: RoundedRectangle(...))
//   3. Replace all .glassBackground() call sites with .glassEffect(.regular, in: RoundedRectangle(...))
//   4. Replace all bare .ultraThinMaterial fills in ProviderCard, LocalProviderCard,
//      SelfHostedProviderCard, and TopicCategoryCard with .glassEffect(.regular, in: <shape>)
//   5. Replace .background(.ultraThinMaterial, in: Capsule()) in EasterEggs.swift with
//      .glassEffect(.regular, in: Capsule())

// MARK: - Adaptive card wrapper

/// Drop-in replacement for GlassCard that uses .glassEffect on iOS 26+.
///
/// Usage:
///   AdaptiveGlassCard(cornerRadius: 16) { ... }
struct AdaptiveGlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    init(
        cornerRadius: CGFloat = OpenMicTheme.Radius.lg,
        padding: CGFloat = OpenMicTheme.Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .adaptiveOpenMicGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - View extensions

extension View {
    /// Applies `.glassEffect(.regular)` on iOS 26+, falls back to `GlassBackground` on iOS 18.
    ///
    /// This is the primary compat entry-point. Replaces bare `.glassBackground()` and
    /// the `.ultraThinMaterial` fills inside ProviderCard / TopicCategoryCard.
    @ViewBuilder
    func adaptiveOpenMicGlass(
        in shape: some Shape = RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg, style: .continuous)
    ) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.modifier(GlassBackground(cornerRadius: OpenMicTheme.Radius.lg))
        }
    }

    /// `.glassEffect(.regular.interactive())` on iOS 26+, `.ultraThinMaterial` capsule on iOS 18.
    ///
    /// Use for tappable pill/chip elements (e.g. EasterEggs capsule button, topic chips).
    @ViewBuilder
    func adaptiveOpenMicGlassInteractive(
        in shape: some Shape = Capsule()
    ) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .contentShape(shape)
        }
    }

    /// `.glassEffect(.regular.tint(color))` on iOS 26+, `.ultraThinMaterial` + tint overlay on iOS 18.
    ///
    /// Use for provider cards that need a branded tint over glass.
    @ViewBuilder
    func adaptiveOpenMicGlassTinted(
        _ color: Color,
        opacity: Double = 0.7,
        in shape: some Shape = RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg, style: .continuous)
    ) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(color), in: shape)
        } else {
            self.background(
                shape
                    .fill(.ultraThinMaterial.opacity(opacity))
            )
        }
    }
}
