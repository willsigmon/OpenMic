import SwiftUI

struct LocalNeuralVoiceSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            Text("LOCAL NEURAL VOICE")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                    HStack(spacing: OpenMicTheme.Spacing.sm) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Piper Neural TTS")
                                .font(OpenMicTheme.Typography.headline)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                            Text("High-quality on-device voice synthesis using neural networks. No cloud, no API key, works offline.")
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }
                    }

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Label("On-Device", systemImage: "iphone")
                        Label("Offline", systemImage: "wifi.slash")
                        Label("Free", systemImage: "dollarsign.circle")
                    }
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.success)
                }
            }

            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    Text("Model: en_US-amy-medium (Piper VITS) \u{2022} ~20MB \u{2022} 22kHz")
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    Spacer()
                }
            }
        }
    }
}
