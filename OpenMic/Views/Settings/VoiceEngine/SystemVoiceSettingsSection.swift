import AVFoundation
import SwiftUI

struct SystemVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices
    @AppStorage("systemTTSSpeechRate") private var speechRate: Double = 0.5
    @AppStorage("systemTTSPitch") private var pitchMultiplier: Double = 1.0

    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var selectedSystemVoiceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            Text("SYSTEM VOICE")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

            // Voice picker
            if availableVoices.isEmpty {
                GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                    HStack(spacing: OpenMicTheme.Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(OpenMicTheme.Colors.accentGradientStart)
                        Text("Loading voices...")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        Spacer()
                    }
                }
            } else {
                // Default option
                voiceRow(
                    name: "Default",
                    detail: "System default English voice",
                    quality: nil,
                    isSelected: selectedSystemVoiceID == nil
                ) {
                    withAnimation(OpenMicTheme.Animation.fast) {
                        selectedSystemVoiceID = nil
                        saveSystemVoice(nil)
                    }
                }

                ForEach(availableVoices, id: \.identifier) { voice in
                    let isSelected = voice.identifier == selectedSystemVoiceID
                    voiceRow(
                        name: voice.name,
                        detail: voiceQualityLabel(voice.quality),
                        quality: voice.quality,
                        isSelected: isSelected
                    ) {
                        withAnimation(OpenMicTheme.Animation.fast) {
                            selectedSystemVoiceID = voice.identifier
                            saveSystemVoice(voice.identifier)
                        }
                    }
                }
            }

            // Speech Rate
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                    HStack {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OpenMicTheme.Colors.speaking)

                        Text("Speech Rate")
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Spacer()

                        Text(speechRateLabel)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                            .monospacedDigit()
                    }

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                        Slider(value: $speechRate, in: 0.3...0.65, step: 0.05)
                            .tint(OpenMicTheme.Colors.speaking)

                        Image(systemName: "hare.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }
                }
            }

            // Pitch
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OpenMicTheme.Colors.listening)

                        Text("Pitch")
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Spacer()

                        Text(pitchLabel)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                            .monospacedDigit()
                    }

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Text("Low")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                        Slider(value: $pitchMultiplier, in: 0.75...1.5, step: 0.05)
                            .tint(OpenMicTheme.Colors.listening)

                        Text("High")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .task { await loadState() }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func voiceRow(
        name: String,
        detail: String,
        quality: AVSpeechSynthesisVoiceQuality?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text(detail)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()

                    if let quality {
                        Text(qualityBadgeText(quality))
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(qualityBadgeColor(quality))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(qualityBadgeColor(quality).opacity(0.12))
                            )
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isSelected
                                ? OpenMicTheme.Colors.accentGradientStart
                                : OpenMicTheme.Colors.textTertiary
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Helpers

    private var speechRateLabel: String {
        if abs(speechRate - 0.5) < 0.01 { return "Normal" }
        if speechRate < 0.4 { return "Slow" }
        if speechRate < 0.5 { return "Relaxed" }
        if speechRate < 0.6 { return "Brisk" }
        return "Fast"
    }

    private var pitchLabel: String {
        if abs(pitchMultiplier - 1.0) < 0.01 { return "Normal" }
        if pitchMultiplier < 1.0 { return "Deeper" }
        return "Higher"
    }

    private func voiceQualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: "Premium \u{2014} most natural"
        case .enhanced: "Enhanced \u{2014} higher quality"
        default: "Standard"
        }
    }

    private func qualityBadgeText(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
    }

    private func qualityBadgeColor(_ quality: AVSpeechSynthesisVoiceQuality) -> Color {
        switch quality {
        case .premium: OpenMicTheme.Colors.accentGradientStart
        case .enhanced: OpenMicTheme.Colors.success
        default: OpenMicTheme.Colors.textTertiary
        }
    }

    // MARK: - Actions

    private func loadState() async {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        availableVoices = allVoices
            .filter { $0.language.hasPrefix("en") }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }

        if let persona = fetchActivePersona(from: appServices) {
            selectedSystemVoiceID = persona.systemTTSVoice
        }
    }

    private func saveSystemVoice(_ identifier: String?) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.systemTTSVoice = identifier
        try? appServices.modelContainer.mainContext.save()
    }
}
