import SwiftUI

// MARK: - AnimatedProgressRing
//
// Standardized progress ring for OpenMic.
// Replaces the inline gauge in UsageDashboardView with a reusable component.
// Color transitions match the usage-tier logic already in the dashboard:
//   cyan (<60%) → amber (60-85%) → red (>85%)
//
// Usage:
//   AnimatedProgressRing(progress: 0.72)
//   AnimatedProgressRing(progress: usageProgress, colorMode: .usage, size: 160, lineWidth: 12)
//     .ringCenter { usageCenterLabel }

struct AnimatedProgressRing<Center: View>: View {
    // MARK: - Color Mode

    enum ColorMode {
        /// Cyan → amber → red based on progress thresholds (for usage gauges)
        case usage
        /// Arbitrary gradient supplied by the caller
        case custom([Color])
    }

    // MARK: - Configuration

    let progress: Double
    var lineWidth: CGFloat = 8
    var colorMode: ColorMode = .custom([OpenMicTheme.Colors.accentGradientStart])
    var size: CGFloat = 80
    var center: (() -> Center)?

    // MARK: - State

    @State private var completionPulse = false
    @State private var completionGlow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init with center

    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        colorMode: ColorMode = .custom([OpenMicTheme.Colors.accentGradientStart]),
        size: CGFloat = 80,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.colorMode = colorMode
        self.size = size
        self.center = center
    }

    var body: some View {
        ZStack {
            completionGlowLayer
            trackCircle
            progressArc
            centerContent
        }
        .frame(width: size, height: size)
        .scaleEffect(completionPulse ? 1.06 : 1.0)
        .onChange(of: progress) { _, newValue in
            guard newValue >= 1.0 else { return }
            triggerCompletionEffect()
        }
        .onAppear {
            if progress >= 1.0 { triggerCompletionEffect() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(Int((progress * 100).rounded())) percent")
        .accessibilityValue(progress >= 1.0 ? "Complete" : "\(Int((progress * 100).rounded()))%")
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var completionGlowLayer: some View {
        if progress >= 1.0 {
            Circle()
                .fill(primaryColor)
                .frame(width: size * 1.25, height: size * 1.25)
                .opacity(completionGlow ? 0.2 : 0)
                .blur(radius: size * 0.15)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: completionGlow
                )
        }
    }

    private var trackCircle: some View {
        Circle()
            .stroke(OpenMicTheme.Colors.surfaceBorder, lineWidth: lineWidth)
    }

    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: min(progress, 1.0))
            .stroke(
                gaugeGradient,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(OpenMicTheme.Animation.smooth, value: progress)
    }

    @ViewBuilder
    private var centerContent: some View {
        if let center {
            center()
        }
    }

    // MARK: - Color helpers

    private var primaryColor: Color {
        switch colorMode {
        case .usage:
            return usageColor
        case .custom(let colors):
            return colors.first ?? OpenMicTheme.Colors.accentGradientStart
        }
    }

    private var usageColor: Color {
        if progress > 0.85 { return OpenMicTheme.Colors.error }
        if progress > 0.60 { return OpenMicTheme.Colors.processing }
        return OpenMicTheme.Colors.accentGradientStart
    }

    private var gaugeGradient: AngularGradient {
        let color = primaryColor
        return AngularGradient(
            colors: [color.opacity(0.5), color],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(progress, 1.0))
        )
    }

    // MARK: - Completion effect

    private func triggerCompletionEffect() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            completionPulse = true
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.25)) {
            completionPulse = false
        }
        completionGlow = true
    }
}

// MARK: - Convenience init (no center label)

extension AnimatedProgressRing where Center == EmptyView {
    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        colorMode: ColorMode = .custom([OpenMicTheme.Colors.accentGradientStart]),
        size: CGFloat = 80
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.colorMode = colorMode
        self.size = size
        self.center = nil
    }
}

// MARK: - Previews

#Preview("Usage Tiers") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            AnimatedProgressRing(progress: 0.35, colorMode: .usage, size: 80) {
                VStack(spacing: 2) {
                    Text("130")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("min left")
                        .font(.caption2)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }
            }
            Text("35% — cyan").font(.caption2)
        }
        VStack(spacing: 8) {
            AnimatedProgressRing(progress: 0.72, colorMode: .usage, size: 80)
            Text("72% — amber").font(.caption2)
        }
        VStack(spacing: 8) {
            AnimatedProgressRing(progress: 0.92, colorMode: .usage, size: 80)
            Text("92% — red").font(.caption2)
        }
        VStack(spacing: 8) {
            AnimatedProgressRing(progress: 1.0, colorMode: .usage, size: 80)
            Text("Complete").font(.caption2)
        }
    }
    .padding()
    .background(OpenMicTheme.Colors.background)
}
