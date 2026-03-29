// Live Activities are iOS-only — not available on Mac Catalyst or Watch extension targets.
#if canImport(ActivityKit) && os(iOS)

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Attributes

/// Static + dynamic data contract for the voice session Live Activity.
///
/// Static fields (on `VoiceSessionAttributes` itself) are set once at start
/// and never change. Dynamic fields live in `ContentState` and are pushed on
/// every voice-state transition.
@available(iOS 16.1, *)
struct VoiceSessionAttributes: ActivityAttributes {
    // MARK: Static (set at session start, immutable)
    /// Display name of the active persona, e.g. "Sigmon".
    let personaName: String
    /// Short provider label, e.g. "OpenAI".
    let providerName: String

    // MARK: Dynamic
    struct ContentState: Codable, Hashable {
        /// Raw voice pipeline state: "listening" | "processing" | "speaking" | "idle"
        var state: String
        /// Seconds since the session began — used for the elapsed-time display.
        var elapsedSeconds: Int
        /// Total messages exchanged in this session.
        var messageCount: Int
    }
}

// MARK: - Widget

/// The Live Activity widget that drives both the Dynamic Island and the Lock Screen.
///
/// This struct belongs in a **widget extension target**, not the main app.
/// Add it to your OpenMicWidgets extension (create one if it doesn't exist yet)
/// and register it in your WidgetBundle.
@available(iOS 16.1, *)
struct VoiceSessionActivityWidget: Widget {
    let kind: String = "VoiceSessionActivityWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoiceSessionAttributes.self) { context in
            // Lock Screen / StandBy / banner on devices without Dynamic Island
            VoiceSessionLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — appears when the user long-presses the compact pill
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeadingView(context: context)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
        }
        .configurationDisplayName("Voice Session")
        .description("Shows the active OpenMic voice conversation.")
    }

    // MARK: - Expanded

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        ZStack {
            Circle()
                .fill(stateColor(context.state.state).opacity(0.18))
                .frame(width: 32, height: 32)
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(stateColor(context.state.state))
        }
        .accessibilityLabel("Persona: \(context.attributes.personaName)")
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        Text(formattedElapsed(context.state.elapsedSeconds))
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel("Elapsed: \(formattedElapsed(context.state.elapsedSeconds))")
    }

    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        VStack(spacing: 2) {
            Text(context.attributes.providerName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(context.attributes.personaName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: stateIcon(context.state.state))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(stateColor(context.state.state))
                .symbolEffect(.pulse, options: .repeating, isActive: context.state.state == "listening")

            Text(stateLabel(context.state.state))
                .font(.caption.weight(.medium))
                .foregroundStyle(stateColor(context.state.state))

            Spacer()

            if context.state.messageCount > 0 {
                Label("\(context.state.messageCount)", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(context.state.messageCount) messages")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Compact

    @ViewBuilder
    private func compactLeadingView(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        Image(systemName: stateIcon(context.state.state))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(stateColor(context.state.state))
            .symbolEffect(.pulse, options: .repeating, isActive: context.state.state == "listening")
            .accessibilityLabel(stateLabel(context.state.state))
    }

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        Text(formattedElapsed(context.state.elapsedSeconds))
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
    }

    // MARK: - Minimal

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<VoiceSessionAttributes>) -> some View {
        Image(systemName: stateIcon(context.state.state))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(stateColor(context.state.state))
            .accessibilityLabel("OpenMic: \(stateLabel(context.state.state))")
    }

    // MARK: - Helpers

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "listening": Color(hex: 0x00E676)
        case "processing": Color(hex: 0xFFAB00)
        case "speaking": Color(hex: 0x448AFF)
        default: Color.white.opacity(0.6)
        }
    }

    private func stateIcon(_ state: String) -> String {
        switch state {
        case "listening": "waveform.badge.microphone"
        case "processing": "ellipsis.circle"
        case "speaking": "waveform"
        default: "mic.slash"
        }
    }

    private func stateLabel(_ state: String) -> String {
        switch state {
        case "listening": "Listening"
        case "processing": "Thinking"
        case "speaking": "Speaking"
        default: "Idle"
        }
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct VoiceSessionLockScreenView: View {
    let context: ActivityViewContext<VoiceSessionAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // State icon
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: stateIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(stateColor)
            }
            .accessibilityHidden(true)

            // Primary info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.personaName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                Text(stateLabel + " · " + context.attributes.providerName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedElapsed)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)

                if context.state.messageCount > 0 {
                    Text("\(context.state.messageCount) msg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "OpenMic voice session: \(context.attributes.personaName), \(stateLabel), elapsed \(formattedElapsed)"
        )
    }

    private var state: String { context.state.state }

    private var stateColor: Color {
        switch state {
        case "listening": Color(hex: 0x00E676)
        case "processing": Color(hex: 0xFFAB00)
        case "speaking": Color(hex: 0x448AFF)
        default: .secondary
        }
    }

    private var stateIcon: String {
        switch state {
        case "listening": "waveform.badge.microphone"
        case "processing": "ellipsis.circle"
        case "speaking": "waveform"
        default: "mic.slash"
        }
    }

    private var stateLabel: String {
        switch state {
        case "listening": "Listening"
        case "processing": "Thinking"
        case "speaking": "Speaking"
        default: "Idle"
        }
    }

    private var formattedElapsed: String {
        let s = context.state.elapsedSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#endif // canImport(ActivityKit) && os(iOS)
