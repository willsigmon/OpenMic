// CustomPullToRefresh.swift
// OpenMic — DesignSystem
//
// Custom pull-to-refresh with a pulsing mic indicator.
// Uses OpenMicTheme tokens and the Haptics engine.
//
// Detection mechanism:
//   A zero-height sensor view at the top of the scroll content reads its own
//   minY in the named coordinate space. Pull past the top edge pushes minY
//   positive. We apply 0.5x resistance and clamp to maxPull.
//
// Usage:
//   ScrollView { ... }
//     .customRefreshable { await viewModel.reload() }

import SwiftUI

// MARK: - Public extension

extension View {
    /// Attaches a custom pull-to-refresh with the OpenMic mic indicator.
    /// Do not combine with `.refreshable` on the same ScrollView.
    func customRefreshable(action: @escaping () async -> Void) -> some View {
        modifier(OpenMicPullToRefreshModifier(action: action))
    }
}

// MARK: - Modifier

private struct OpenMicPullToRefreshModifier: ViewModifier {
    let action: () async -> Void

    private static let coordinateSpaceName = "openmic.ptr"

    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var hasTriggeredHaptic = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Const {
        static let threshold: CGFloat = 60
        static let maxPull: CGFloat = 120
        static let resistance: CGFloat = 0.5
        static let indicatorSize: CGFloat = 44
    }

    private var pullFraction: CGFloat {
        min(pullOffset / Const.threshold, 1.0)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
                .overlay(alignment: .top) {
                    overscrollSensor
                }

            if pullOffset > 0 || isRefreshing {
                MicPTRIndicator(
                    fraction: pullFraction,
                    isRefreshing: isRefreshing,
                    reduceMotion: reduceMotion
                )
                .frame(width: Const.indicatorSize, height: Const.indicatorSize)
                .offset(y: isRefreshing
                    ? Const.threshold - Const.indicatorSize
                    : pullOffset - Const.indicatorSize
                )
                .animation(
                    reduceMotion ? .linear(duration: 0.01) : OpenMicTheme.Animation.fast,
                    value: isRefreshing
                )
            }
        }
        .coordinateSpace(name: Self.coordinateSpaceName)
    }

    // MARK: - Overscroll sensor

    private var overscrollSensor: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(Self.coordinateSpaceName)).minY
            Color.clear
                .onChange(of: minY) { _, newY in
                    onScrollOffsetChange(newY)
                }
        }
        .frame(height: 0)
    }

    // MARK: - Scroll tracking

    private func onScrollOffsetChange(_ rawY: CGFloat) {
        guard !isRefreshing else { return }

        if rawY > 0 {
            let damped = min(rawY * Const.resistance, Const.maxPull)
            if abs(damped - pullOffset) > 0.5 {
                pullOffset = damped
            }

            if damped >= Const.threshold && !hasTriggeredHaptic {
                hasTriggeredHaptic = true
                Haptics.impact()
            }
        } else if pullOffset > 0 {
            onRelease()
        }
    }

    private func onRelease() {
        if pullOffset >= Const.threshold {
            triggerRefresh()
        } else {
            retract()
        }
    }

    private func triggerRefresh() {
        withAnimation(reduceMotion ? .linear(duration: 0.01) : OpenMicTheme.Animation.springy) {
            isRefreshing = true
            pullOffset = Const.threshold
        }
        Task {
            await action()
            await MainActor.run { finish() }
        }
    }

    private func retract() {
        withAnimation(reduceMotion ? .linear(duration: 0.01) : OpenMicTheme.Animation.springy) {
            pullOffset = 0
        }
        hasTriggeredHaptic = false
    }

    private func finish() {
        withAnimation(reduceMotion ? .linear(duration: 0.01) : OpenMicTheme.Animation.springy) {
            isRefreshing = false
            pullOffset = 0
        }
        hasTriggeredHaptic = false
    }
}

// MARK: - Mic Indicator

/// A microphone icon that grows and glows as the user pulls.
/// Once refreshing, the mic pulses continuously using a repeat animation.
private struct MicPTRIndicator: View {
    let fraction: CGFloat
    let isRefreshing: Bool
    let reduceMotion: Bool

    @State private var pulsing = false

    var body: some View {
        ZStack {
            // Glow ring — grows with pull fraction
            Circle()
                .fill(OpenMicTheme.Colors.glowCyan)
                .scaleEffect(reduceMotion ? 1 : (0.5 + fraction * 0.8))
                .opacity(Double(fraction) * 0.6)

            // Mic icon — scales from 0.4 to 1 as fraction grows
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [OpenMicTheme.Colors.accentGradientStart,
                                 OpenMicTheme.Colors.accentGradientEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(isRefreshing && !reduceMotion ? (pulsing ? 1.18 : 1.0) : max(0.4, fraction))
        }
        .scaleEffect(reduceMotion ? 1 : fraction)
        .opacity(Double(fraction))
        .onChange(of: isRefreshing) { _, spinning in
            if spinning && !reduceMotion {
                withAnimation(OpenMicTheme.Animation.pulse) {
                    pulsing = true
                }
            } else {
                pulsing = false
            }
        }
        .accessibilityLabel(isRefreshing ? "Refreshing" : "Pull to refresh")
        .accessibilityValue(isRefreshing ? "Loading" : "\(Int(fraction * 100))%")
    }
}

// MARK: - Preview

#Preview("OpenMic PTR") {
    struct Demo: View {
        @State private var items = Array(1...15)

        var body: some View {
            NavigationStack {
                ZStack {
                    OpenMicTheme.Colors.background.ignoresSafeArea()
                    ScrollView {
                        LazyVStack(spacing: OpenMicTheme.Spacing.sm) {
                            ForEach(items, id: \.self) { i in
                                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md, style: .continuous)
                                    .fill(OpenMicTheme.Colors.surfacePrimary)
                                    .frame(height: 72)
                                    .overlay(
                                        Text("Conversation \(i)")
                                            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                                    )
                            }
                        }
                        .padding(OpenMicTheme.Spacing.md)
                    }
                    .customRefreshable {
                        try? await Task.sleep(for: .seconds(1.5))
                        items = Array(1...15).shuffled()
                    }
                }
                .navigationTitle("History")
            }
        }
    }
    return Demo()
}
