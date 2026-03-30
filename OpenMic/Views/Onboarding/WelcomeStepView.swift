import SwiftUI

struct WelcomeStepView: View {
    let viewModel: OnboardingViewModel

    @State private var showContent = false
    @State private var showFeature1 = false
    @State private var showFeature2 = false
    @State private var showFeature3 = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            // Background: animated mesh gradient (iOS 18+) / blob fallback (iOS 17)
            AnimatedMeshBackground()
                .ignoresSafeArea()

            // Ambient orbs still run on top for light-mode depth
            ambientOrbs

            VStack(spacing: OpenMicTheme.Spacing.xxl) {
                Spacer()

                // Hero icon
                heroIcon
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // Title
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Text("OpenMic")
                        .font(OpenMicTheme.Typography.heroTitle)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Text("Your AI copilot for the road.\nJust talk — I'll handle the rest.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 15)

                Spacer()

                // Feature cards — staggered entrance
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    FeatureCard(
                        icon: "mic.fill",
                        title: "Talk Naturally",
                        description: "Like calling your smartest friend",
                        color: OpenMicTheme.Colors.accentGradientStart,
                        accentShape: .ring
                    )
                    .opacity(showFeature1 ? 1 : 0)
                    .offset(x: showFeature1 ? 0 : -30)

                    FeatureCard(
                        icon: "car.fill",
                        title: "Built for Driving",
                        description: "CarPlay ready, eyes-free design",
                        color: OpenMicTheme.Colors.speaking,
                        accentShape: .rays
                    )
                    .opacity(showFeature2 ? 1 : 0)
                    .offset(x: showFeature2 ? 0 : -30)

                    FeatureCard(
                        icon: "sparkles",
                        title: "Pick Your Brain",
                        description: "OpenAI, Claude, Gemini, Grok & more",
                        color: OpenMicTheme.Colors.processing,
                        accentShape: .sparkle
                    )
                    .opacity(showFeature3 ? 1 : 0)
                    .offset(x: showFeature3 ? 0 : -30)
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xl)

                Spacer()

                // Continue button
                Button("Let's Go") {
                    Haptics.impact()
                    viewModel.advance()
                }
                .buttonStyle(.openMicPrimary)
                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 10)
            }
        }
        .onAppear {
            // Staggered entrance — each element cascades in
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showFeature1 = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
                showFeature2 = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showFeature3 = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
                showButton = true
            }
        }
    }

    @ViewBuilder
    private var heroIcon: some View {
        GradientIcon(
            systemName: "car.fill",
            gradient: OpenMicTheme.Gradients.accent,
            size: 80,
            iconSize: 36,
            glowColor: OpenMicTheme.Colors.glowCyan,
            isAnimated: true
        )
    }

    @ViewBuilder
    private var ambientOrbs: some View {
        GeometryReader { geo in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OpenMicTheme.Colors.accentGradientStart.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * 0.4
                    )
                )
                .frame(width: geo.size.width * 0.7)
                .offset(x: -geo.size.width * 0.15, y: -geo.size.height * 0.1)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OpenMicTheme.Colors.accentGradientEnd.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * 0.35
                    )
                )
                .frame(width: geo.size.width * 0.5)
                .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.6)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let accentShape: LayeredFeatureIcon.AccentShape

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.md) {
                LayeredFeatureIcon(
                    systemName: icon,
                    color: color,
                    accentShape: accentShape
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                    Text(description)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}
