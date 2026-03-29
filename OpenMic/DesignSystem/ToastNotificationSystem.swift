// ToastNotificationSystem.swift
// OpenMic — DesignSystem
//
// Queue-backed, one-at-a-time toast system ported from Modcaster.
//
// Usage:
//   ToastManager.shared.show(.voiceState("Now using Claude"))
//   ToastManager.shared.show(.success("API key saved"))
//   ToastManager.shared.show(.info("Conversation copied"))
//
// Wire into any root view:
//   MainTabView().toastOverlay()
//
// Architecture notes:
//   - @Observable + @MainActor means SwiftUI can observe currentToast directly
//     without a separate publisher or environment injection.
//   - The dismiss Task is stored and cancelled on manual dismiss to prevent a
//     double-pop when the user taps before the timer fires.
//   - All animation constants reference OpenMicTheme.Animation for consistency.
//   - Haptics go through the existing Haptics enum — no new dependency created.

import SwiftUI

// MARK: - Toast Style

/// Semantic styles that drive visual and haptic treatment for each toast.
public enum ToastStyle: Equatable {

    /// Neutral informational message.
    case info(String)

    /// Positive confirmation — key saved, action succeeded.
    case success(String)

    /// Rich achievement card with title, subtitle, and an SF Symbol icon.
    case achievement(title: String, subtitle: String, icon: String)

    /// Brief voice-state transition label unique to OpenMic.
    /// Example: "Now using Claude", "Switched to GPT-4o".
    case voiceState(String)

    // MARK: Derived

    var message: String {
        switch self {
        case .info(let msg): return msg
        case .success(let msg): return msg
        case .achievement(_, let subtitle, _): return subtitle
        case .voiceState(let msg): return msg
        }
    }

    var title: String? {
        switch self {
        case .achievement(let title, _, _): return title
        default: return nil
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .achievement(_, _, let icon): return icon
        case .voiceState: return "waveform.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .info: return OpenMicTheme.Colors.textTertiary
        case .success: return OpenMicTheme.Colors.success
        case .achievement: return OpenMicTheme.Colors.accentGradientStart
        case .voiceState: return OpenMicTheme.Colors.speaking
        }
    }

    /// Duration the toast stays visible before auto-dismiss.
    var defaultDuration: TimeInterval {
        switch self {
        case .info: return 2.5
        case .success: return 2.5
        case .achievement: return 3.5
        case .voiceState: return 2.0
        }
    }
}

// MARK: - Toast Item

/// Value type representing a single queued toast.
public struct ToastItem: Identifiable, Equatable {
    public let id: UUID
    public let style: ToastStyle
    /// Override the default auto-dismiss duration when needed.
    public let duration: TimeInterval

    public init(
        id: UUID = UUID(),
        style: ToastStyle,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.style = style
        self.duration = duration ?? style.defaultDuration
    }
}

// MARK: - Toast Manager

@Observable
@MainActor
public final class ToastManager {

    // MARK: Singleton

    public static let shared = ToastManager()

    // MARK: State

    /// The toast currently visible on screen. `nil` when none is shown.
    public private(set) var currentToast: ToastItem?

    // MARK: Private State

    private var queue: [ToastItem] = []
    private var isDraining = false
    /// Retained so we can cancel the auto-dismiss race on manual tap-to-dismiss.
    private var dismissTask: Task<Void, Never>?

    // MARK: Init

    private init() {}

    // MARK: Public API

    /// Enqueue a toast for display. Safe to call from any @MainActor context.
    public func show(_ style: ToastStyle, duration: TimeInterval? = nil) {
        let item = ToastItem(style: style, duration: duration)
        queue.append(item)
        drainIfNeeded()
    }

    // MARK: Convenience

    public func showInfo(_ message: String) {
        show(.info(message))
    }

    public func showSuccess(_ message: String) {
        show(.success(message))
    }

    public func showAchievement(title: String, subtitle: String, icon: String) {
        show(.achievement(title: title, subtitle: subtitle, icon: icon))
    }

    public func showVoiceState(_ message: String) {
        show(.voiceState(message))
    }

    // MARK: Manual Dismiss

    /// Dismiss the currently visible toast immediately (e.g. on user tap).
    public func dismissCurrent() {
        dismissTask?.cancel()
        dismissTask = nil
        hideCurrent()
    }

    // MARK: Private Queue Logic

    private func drainIfNeeded() {
        guard !isDraining, !queue.isEmpty else { return }
        isDraining = true
        showNext()
    }

    private func showNext() {
        guard !queue.isEmpty else {
            isDraining = false
            return
        }

        let next = queue.removeFirst()
        triggerHaptic(for: next.style)

        withAnimation(OpenMicTheme.Animation.springy) {
            currentToast = next
        }

        dismissTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(next.duration))
            guard !Task.isCancelled else { return }
            self.hideCurrent()
        }
    }

    private func hideCurrent() {
        withAnimation(OpenMicTheme.Animation.fast) {
            currentToast = nil
        }

        // Brief gap so the spring exit animation completes before the next toast enters.
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(150))
            self.showNext()
        }
    }

    private func triggerHaptic(for style: ToastStyle) {
        switch style {
        case .info:
            Haptics.tap()
        case .success:
            Haptics.success()
        case .achievement:
            Haptics.celebrationPattern()
        case .voiceState:
            Haptics.select()
        }
    }
}

// MARK: - Toast Card View

/// The visual card rendered for each toast.
/// Achievement style gets a two-line layout; all others use a single-line compact layout.
public struct ToastCardView: View {
    let toast: ToastItem

    @State private var iconBounce = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        HStack(alignment: .center, spacing: OpenMicTheme.Spacing.sm) {
            Image(systemName: toast.style.icon)
                .font(.system(size: OpenMicTheme.IconSize.md, weight: .semibold))
                .foregroundStyle(toast.style.accentColor)
                .symbolEffect(.bounce, value: iconBounce)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.style.title {
                    Text(title)
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                        .lineLimit(1)
                }

                Text(toast.style.message)
                    .font(
                        toast.style.title != nil
                            ? OpenMicTheme.Typography.callout
                            : OpenMicTheme.Typography.body
                    )
                    .foregroundStyle(
                        toast.style.title != nil
                            ? OpenMicTheme.Colors.textSecondary
                            : OpenMicTheme.Colors.textPrimary
                    )
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OpenMicTheme.Spacing.md)
        .padding(.vertical, OpenMicTheme.Spacing.sm)
        .glassBackground(cornerRadius: OpenMicTheme.Radius.lg)
        .shadow(
            color: .black.opacity(0.18),
            radius: 14,
            x: 0,
            y: 5
        )
        .padding(.horizontal, OpenMicTheme.Spacing.md)
        .onAppear {
            guard !reduceMotion else { return }
            // Delay icon bounce so it fires after the spring entrance settles.
            Task {
                try? await Task.sleep(for: .milliseconds(220))
                iconBounce += 1
            }
        }
    }
}

// MARK: - Toast Overlay Modifier

/// Pins the toast at the top of the view hierarchy, above all content.
/// Apply exactly once, to the root view.
public struct ToastOverlayModifier: ViewModifier {
    @State private var manager = ToastManager.shared

    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let toast = manager.currentToast {
                ToastCardView(toast: toast)
                    .padding(.top, OpenMicTheme.Spacing.xs)
                    .zIndex(1000)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    .onTapGesture {
                        manager.dismissCurrent()
                    }
                    // id forces SwiftUI to re-run the transition for each new toast
                    // even when two successive toasts share the same style type.
                    .id(toast.id)
            }
        }
        .animation(OpenMicTheme.Animation.springy, value: manager.currentToast?.id)
    }
}

public extension View {
    /// Attach toast notification support to a view hierarchy.
    /// Apply once on the root view — typically `MainTabView`.
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}

// MARK: - Preview

#Preview("Toast Styles") {
    struct PreviewContent: View {
        var body: some View {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: OpenMicTheme.Spacing.md) {
                    Button("Info") {
                        ToastManager.shared.showInfo("Conversation copied")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Success") {
                        ToastManager.shared.showSuccess("API key saved")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Achievement") {
                        ToastManager.shared.showAchievement(
                            title: "First Conversation",
                            subtitle: "You started your first chat",
                            icon: "star.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Voice State") {
                        ToastManager.shared.showVoiceState("Now using Claude")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .toastOverlay()
        }
    }

    return PreviewContent()
}
