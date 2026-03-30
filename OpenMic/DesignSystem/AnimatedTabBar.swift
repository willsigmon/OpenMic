// AnimatedTabBar.swift
// OpenMic
//
// "Midnight Dashboard" custom animated tab bar.
// Replaces the native UIKit tab bar in MainTabView.
//
// Wire-up:
//   1. Add `.toolbar(.hidden, for: .tabBar)` to the TabView in MainTabView.
//   2. Place OpenMicAnimatedTabBar as a `.safeAreaInset(edge: .bottom, spacing: 0)`.
//
// Design contract:
//   - A cyan glass capsule slides between tabs via matchedGeometryEffect.
//   - Icons bounce on selection via .symbolEffect(.bounce).
//   - "Talk" tab mic icon adapts by voice state:
//       .idle   → static mic, subtle cyan tint
//       active  → .symbolEffect(.variableColor.iterative) — cyan pulse
//   - Haptics.tabSwitch() fires on every selection change.
//   - @Environment(\.accessibilityReduceMotion) disables sliding and bouncing;
//     selection becomes an instant tint swap only.
//   - @Environment(\.accessibilityReduceTransparency) replaces glass background
//     with a solid opaque surface.
//   - Unread badge count rendered as a pill overlay on any tab.

import SwiftUI

// MARK: - Tab Item Model

struct OpenMicTabItem: Identifiable {
    let id: MainTabView.Tab
    let icon: String
    let selectedIcon: String
    let title: String
    var badge: Int
    /// When true the icon uses the special mic-with-state rendering.
    var isSpecial: Bool

    init(
        id: MainTabView.Tab,
        icon: String,
        selectedIcon: String? = nil,
        title: String,
        badge: Int = 0,
        isSpecial: Bool = false
    ) {
        self.id = id
        self.icon = icon
        self.selectedIcon = selectedIcon ?? (icon + ".fill")
        self.title = title
        self.badge = badge
        self.isSpecial = isSpecial
    }
}

// MARK: - Voice State for Mic Animation
//
// The tab bar does not import VoiceSessionState directly to avoid coupling.
// The call site maps to this lightweight enum at the boundary.

enum MicActivityState: Equatable {
    case idle
    case active // listening, processing, or speaking — drives variableColor
}

// MARK: - Animated Tab Bar

struct OpenMicAnimatedTabBar: View {

    @Binding var selection: MainTabView.Tab
    let tabs: [OpenMicTabItem]
    /// Controls the mic icon animation on the Talk tab.
    let micState: MicActivityState
    /// Unread conversation badge for the History tab (0 hides it).
    var historyBadge: Int = 0

    @Namespace private var indicatorNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 4) // safeAreaInset adds home indicator clearance
        .background(barBackground)
    }

    // MARK: - Background

    @ViewBuilder
    private var barBackground: some View {
        if reduceTransparency {
            Color(uiColor: .systemBackground)
                .overlay(alignment: .top) { topDivider }
        } else {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Midnight Dashboard deep-surface wash
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                OpenMicTheme.Colors.surfaceGlass.opacity(0.88),
                                OpenMicTheme.Colors.surfaceSecondary.opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle cyan accent at leading edge
                LinearGradient(
                    colors: [
                        OpenMicTheme.Colors.accentGradientStart.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .overlay(alignment: .top) { topDivider }
        }
    }

    private var topDivider: some View {
        LinearGradient(
            colors: [
                OpenMicTheme.Colors.borderStrong.opacity(colorScheme == .dark ? 0.6 : 0.3),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 0.5)
    }

    // MARK: - Per-Tab Button

    @ViewBuilder
    private func tabButton(_ tab: OpenMicTabItem) -> some View {
        let isSelected = tab.id == selection
        let effectiveBadge: Int = tab.id == .history ? historyBadge : tab.badge

        Button {
            guard selection != tab.id else { return }
            if reduceMotion {
                selection = tab.id
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    selection = tab.id
                }
            }
            Haptics.tabSwitch()
        } label: {
            if tab.isSpecial {
                specialTabLabel(tab: tab, isSelected: isSelected)
            } else {
                standardTabLabel(tab: tab, isSelected: isSelected, badge: effectiveBadge)
            }
        }
        .buttonStyle(OpenMicTabButtonStyle(reduceMotion: reduceMotion))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "" : "Switch to \(tab.title)")
    }

    // MARK: - Standard Tab Label

    @ViewBuilder
    private func standardTabLabel(
        tab: OpenMicTabItem,
        isSelected: Bool,
        badge: Int
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                ZStack {
                    // Sliding cyan capsule pill
                    Capsule()
                        .fill(
                            OpenMicTheme.Colors.accentGradientStart.opacity(
                                isSelected ? 0.18 : 0.0
                            )
                        )
                        .frame(width: 52, height: 32)
                        .matchedGeometryEffect(
                            id: "openMicTabPill",
                            in: indicatorNamespace,
                            isSource: isSelected
                        )

                    OpenMicTabIconView(
                        icon: tab.icon,
                        selectedIcon: tab.selectedIcon,
                        isSelected: isSelected,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: 52, height: 32)
                }

                Text(tab.title)
                    .font(.system(.caption2, design: .default).weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? OpenMicTheme.Colors.accentGradientStart
                            : OpenMicTheme.Colors.textSecondary
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                        value: isSelected
                    )
            }

            if badge > 0 {
                OpenMicTabBadge(count: badge)
                    .offset(x: 6, y: -4)
            }
        }
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }

    // MARK: - Special (Talk / Mic) Tab Label
    //
    // Idle → static mic.fill with subtle cyan tint.
    // Active → variableColor.iterative on mic.fill — visualises voice activity.
    // Selected → cyan gradient glow ring behind the icon.

    @ViewBuilder
    private func specialTabLabel(tab: OpenMicTabItem, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                // Active glow ring — only when selected or mic is live
                if (isSelected || micState == .active) && !reduceMotion {
                    Circle()
                        .fill(OpenMicTheme.Colors.accentGradientStart.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .blur(radius: 8)
                }

                // Sliding pill — keeps the indicator geometry consistent
                Capsule()
                    .fill(
                        OpenMicTheme.Colors.accentGradientStart.opacity(
                            isSelected ? 0.18 : 0.0
                        )
                    )
                    .frame(width: 52, height: 32)
                    .matchedGeometryEffect(
                        id: "openMicTabPill",
                        in: indicatorNamespace,
                        isSource: isSelected
                    )

                TalkMicIconView(
                    isSelected: isSelected,
                    micState: micState,
                    reduceMotion: reduceMotion
                )
                .frame(width: 52, height: 32)
            }

            Text(tab.title)
                .font(.system(.caption2, design: .default).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                        ? OpenMicTheme.Colors.accentGradientStart
                        : OpenMicTheme.Colors.textSecondary
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                    value: isSelected
                )
        }
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }
}

// MARK: - Standard Icon View

private struct OpenMicTabIconView: View {
    let icon: String
    let selectedIcon: String
    let isSelected: Bool
    let reduceMotion: Bool

    @State private var bounceTrigger = false

    var body: some View {
        Image(systemName: isSelected ? selectedIcon : icon)
            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(
                isSelected
                    ? OpenMicTheme.Colors.accentGradientStart
                    : OpenMicTheme.Colors.textSecondary
            )
            .symbolEffect(.bounce, value: bounceTrigger)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                value: isSelected
            )
            .onChange(of: isSelected) { _, selected in
                guard selected, !reduceMotion else { return }
                bounceTrigger.toggle()
            }
    }
}

// MARK: - Talk / Mic Icon View

private struct TalkMicIconView: View {
    let isSelected: Bool
    let micState: MicActivityState
    let reduceMotion: Bool

    @State private var bounceTrigger = false

    private var iconColor: Color {
        guard isSelected || micState == .active else {
            return OpenMicTheme.Colors.textSecondary
        }
        return OpenMicTheme.Colors.accentGradientStart
    }

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(iconColor)
            .symbolEffect(.bounce, value: bounceTrigger)
            // variableColor fires only when the mic is actively in use
            .symbolEffect(
                .variableColor.iterative,
                isActive: micState == .active && !reduceMotion
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                value: isSelected
            )
            .onChange(of: isSelected) { _, selected in
                guard selected, !reduceMotion else { return }
                bounceTrigger.toggle()
            }
    }
}

// MARK: - Button Style

private struct OpenMicTabButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Badge

private struct OpenMicTabBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 5 : 0)
                .frame(minWidth: 16, minHeight: 16)
                .background(
                    Capsule()
                        .fill(OpenMicTheme.Colors.accentGradientStart)
                        .shadow(
                            color: OpenMicTheme.Colors.accentGradientStart.opacity(0.45),
                            radius: 3,
                            y: 1
                        )
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("OpenMic Animated Tab Bar") {
    struct Wrapper: View {
        @State private var selection: MainTabView.Tab = .talk
        @State private var micActive = false
        @State private var historyBadge = 3

        private let tabs: [OpenMicTabItem] = [
            OpenMicTabItem(id: .talk,     icon: "mic",                    title: "Talk",     isSpecial: true),
            OpenMicTabItem(id: .topics,   icon: "sparkles.rectangle.stack", title: "Topics"),
            OpenMicTabItem(id: .history,  icon: "clock",                  title: "History"),
            OpenMicTabItem(id: .settings, icon: "gearshape",              title: "Settings")
        ]

        var body: some View {
            ZStack(alignment: .bottom) {
                Color(hex: 0x0A0A0F)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Toggle("Mic Active", isOn: $micActive)
                        Stepper("History badge: \(historyBadge)", value: $historyBadge, in: 0...99)
                    }
                    .tint(OpenMicTheme.Colors.accentGradientStart)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 120)
                    .foregroundStyle(.white)
                }

                OpenMicAnimatedTabBar(
                    selection: $selection,
                    tabs: tabs,
                    micState: micActive ? .active : .idle,
                    historyBadge: historyBadge
                )
            }
            .preferredColorScheme(.dark)
        }
    }

    return Wrapper()
}
#endif
