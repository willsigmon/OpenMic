import SwiftUI

struct UsageDashboardView: View {
    @Environment(AppServices.self) private var appServices
    @State private var showContent = false
    @State private var showPaywall = false

    private var tier: SubscriptionTier { appServices.effectiveTier }
    private var remaining: Int { appServices.usageTracker.remainingMinutes }
    private var total: Int { tier.monthlyMinutes }
    private var used: Int { max(0, total - remaining) }
    private var progress: Double {
        guard total > 0, total != .max else { return 0 }
        return Double(used) / Double(total)
    }

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: OpenMicTheme.Spacing.xl) {
                    // Circular usage gauge
                    usageGauge
                        .padding(.top, OpenMicTheme.Spacing.xl)
                        .opacity(showContent ? 1 : 0)

                    // Current plan info
                    planInfoCard
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .opacity(showContent ? 1 : 0)

                    // Usage breakdown
                    usageBreakdownCard
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .opacity(showContent ? 1 : 0)

                    // Upgrade CTA (only for free/standard)
                    if tier == .free || tier == .standard {
                        upgradeCard
                            .padding(.horizontal, OpenMicTheme.Spacing.md)
                            .opacity(showContent ? 1 : 0)
                    }
                }
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .navigationTitle("Usage")
        .onAppear {
            withAnimation(OpenMicTheme.Animation.smooth.delay(0.1)) {
                showContent = true
            }
        }
        .task {
            await appServices.usageTracker.refreshQuota(tier: tier)
        }
    }

    // MARK: - Usage Gauge

    private var usageGauge: some View {
        VStack(spacing: OpenMicTheme.Spacing.md) {
            AnimatedProgressRing(
                progress: progress,
                lineWidth: 12,
                colorMode: .usage,
                size: 160
            ) {
                VStack(spacing: 2) {
                    if tier == .byok {
                        Image(systemName: "infinity")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                    } else {
                        Text("\(remaining)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                            .contentTransition(.numericText())
                            .animation(OpenMicTheme.Animation.smooth, value: remaining)
                    }

                    Text("min left")
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }
            }

            if tier != .byok {
                Text("\(used) of \(total) minutes used this month")
                    .font(OpenMicTheme.Typography.body)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                    .contentTransition(.numericText())
                    .animation(OpenMicTheme.Animation.smooth, value: used)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tier == .byok
            ? "Unlimited usage, Power User mode"
            : "\(remaining) minutes remaining out of \(total)")
    }

    // MARK: - Plan Info

    private var planInfoCard: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.lg, padding: OpenMicTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    Text(tier.displayName)
                        .font(OpenMicTheme.Typography.title)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Voice Quality")
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    Text(tier.voiceQualityDescription)
                        .font(OpenMicTheme.Typography.callout)
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    // MARK: - Usage Breakdown

    private var usageBreakdownCard: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.lg, padding: OpenMicTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                Text("This Month")
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                UsageRow(
                    label: "Minutes Used",
                    value: tier == .byok ? "--" : "\(used)",
                    icon: "clock",
                    color: OpenMicTheme.Colors.accentGradientStart
                )

                UsageRow(
                    label: "Sessions",
                    value: "\(appServices.usageTracker.sessionCount)",
                    icon: "bubble.left.and.bubble.right",
                    color: OpenMicTheme.Colors.speaking
                )

                UsageRow(
                    label: "Max Session",
                    value: tier == .byok ? "Unlimited" : "\(tier.maxSessionMinutes) min",
                    icon: "timer",
                    color: OpenMicTheme.Colors.processing
                )
            }
        }
    }

    // MARK: - Upgrade Card

    private var upgradeCard: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.lg, padding: OpenMicTheme.Spacing.md) {
            VStack(spacing: OpenMicTheme.Spacing.sm) {
                let nextTier: SubscriptionTier = tier == .free ? .standard : .premium

                Text("Upgrade to \(nextTier.displayName)")
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                Text(nextTier.voiceQualityDescription)
                    .font(OpenMicTheme.Typography.caption)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)

                Button("View Plans") {
                    Haptics.tap()
                    showPaywall = true
                }
                .buttonStyle(.openMicPrimary)
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
            }
        }
    }
}

// MARK: - Usage Row

private struct UsageRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: OpenMicTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(OpenMicTheme.Typography.body)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(OpenMicTheme.Typography.headline)
                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}
