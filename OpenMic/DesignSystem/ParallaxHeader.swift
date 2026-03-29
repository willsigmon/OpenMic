import SwiftUI

// MARK: - Scroll Offset Preference Key

/// Propagates the global minY of the header's background up to the ScrollView ancestor.
struct OpenMicScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Parallax Header

/// A generic parallax hero header adapted to OpenMic's glass aesthetic.
///
/// Behaviour (when `reduceMotion` is false):
/// - Pull-down: content zooms up (scale) and stays pinned to the top edge.
/// - Scroll-up: content translates at `parallaxSpeed`× scroll speed and
///   progressively blurs up to `maxBlur` points.
/// - Nav-bar: drives `navBarOpacity` from 0 (transparent) to 1 (glass material).
///
/// When `reduceMotion` is true all transforms are suppressed; the header
/// renders as a plain static view to respect the user's system preference.
///
/// Usage:
/// ```swift
/// ParallaxHeader(reduceMotion: reduceMotion, navBarOpacity: $navBarOpacity) {
///     TopicsHeroView()
/// }
/// ```
struct OpenMicParallaxHeader<Content: View>: View {

    // MARK: - Configuration

    /// Height of the header in the identity (non-scrolled) position.
    var height: CGFloat = 280

    /// Parallax translation multiplier for upward scroll (0…1).
    var parallaxSpeed: CGFloat = 0.5

    /// Maximum blur radius applied while scrolling upward.
    var maxBlur: CGFloat = 10

    /// Pull-down scale intensity divisor — lower = more aggressive zoom.
    var pullDownIntensity: CGFloat = 500

    /// When `true`, all motion effects are suppressed.
    var reduceMotion: Bool

    /// Driven by scroll offset. 0 = transparent nav bar; 1 = glass material.
    @Binding var navBarOpacity: Double

    @ViewBuilder var content: () -> Content

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let offset = proxy.frame(in: .global).minY

            contentLayer(offset: offset)
                .preference(key: OpenMicScrollOffsetKey.self, value: offset)
        }
        .frame(height: height)
        .onPreferenceChange(OpenMicScrollOffsetKey.self) { offset in
            updateNavBarOpacity(for: offset)
        }
    }

    // MARK: - Content layer

    @ViewBuilder
    private func contentLayer(offset: CGFloat) -> some View {
        if reduceMotion {
            content()
                .frame(height: height)
                .clipped()
        } else {
            let isPullingDown = offset > 0
            let scaleAmount: CGFloat = isPullingDown ? 1 + offset / pullDownIntensity : 1
            let translateY: CGFloat = isPullingDown ? -offset / 2 : -offset * parallaxSpeed
            let blurAmount: CGFloat = offset < 0 ? min(maxBlur, -offset / 20) : 0
            let expandedHeight: CGFloat = height + (isPullingDown ? offset : 0)

            content()
                .frame(height: expandedHeight)
                .clipped()
                .scaleEffect(scaleAmount, anchor: .center)
                .offset(y: translateY)
                .blur(radius: blurAmount)
        }
    }

    // MARK: - Nav bar opacity

    private func updateNavBarOpacity(for offset: CGFloat) {
        guard !reduceMotion else {
            navBarOpacity = 1
            return
        }
        let threshold: CGFloat = -50
        let fullyOpaque: CGFloat = -120
        let clamped = max(threshold, min(fullyOpaque, offset))
        let progress = (clamped - threshold) / (fullyOpaque - threshold)
        navBarOpacity = Double(progress)
    }
}

// MARK: - Hero Banner

/// A pre-composed hero banner for use as `OpenMicParallaxHeader` content.
/// Displays the OpenMic app logo and tagline over the ambient background.
struct OpenMicHeroBanner: View {
    var title: String
    var subtitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Ambient glass background — mirrors the app's cockpit aesthetic.
            OpenMicTheme.Colors.background
                .overlay {
                    // Subtle radial glow behind the logo.
                    RadialGradient(
                        colors: [
                            OpenMicTheme.Colors.glowCyan,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                    .blendMode(.plusLighter)
                }

            VStack(spacing: OpenMicTheme.Spacing.xs) {
                // App logo mark.
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                OpenMicTheme.Colors.accentGradientStart,
                                OpenMicTheme.Colors.accentGradientEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: OpenMicTheme.Colors.glowCyan, radius: 12)
                    .accessibilityHidden(true)

                Text(title)
                    .font(OpenMicTheme.Typography.title)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, OpenMicTheme.Spacing.xl)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Conversation List Hero Banner

/// A pre-composed "Your Conversations" hero banner for `ConversationListView`.
struct ConversationListHeroBanner: View {
    let conversationCount: Int

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background
                .overlay {
                    RadialGradient(
                        colors: [
                            OpenMicTheme.Colors.glowBlue,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                    .blendMode(.plusLighter)
                }

            VStack(spacing: OpenMicTheme.Spacing.xs) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                OpenMicTheme.Colors.accentGradientStart,
                                OpenMicTheme.Colors.accentGradientEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: OpenMicTheme.Colors.glowBlue, radius: 10)
                    .accessibilityHidden(true)

                Text("Your Conversations")
                    .font(OpenMicTheme.Typography.title)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                if conversationCount > 0 {
                    Text("\(conversationCount) saved")
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .contentTransition(.numericText())
                        .animation(OpenMicTheme.Animation.standard, value: conversationCount)
                }
            }
            .padding(.horizontal, OpenMicTheme.Spacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Conversations, \(conversationCount) saved")
    }
}

// MARK: - Nav Bar Glass Modifier

/// Drives nav bar glass visibility from the parallax scroll offset.
/// Requires iOS 18 for `toolbarBackgroundVisibility`; falls back to always-visible on iOS 17.
struct OpenMicGlassNavBarModifier: ViewModifier {
    let opacity: Double

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .toolbarBackgroundVisibility(opacity > 0.1 ? .visible : .hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

// MARK: - Scroll Transition for Cards

extension View {
    /// Edge fade for topic category cards and conversation rows.
    /// Fades + scales cards as they enter/exit the scroll viewport.
    @ViewBuilder
    func openMicScrollTransition() -> some View {
        self.scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.5)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }
}
