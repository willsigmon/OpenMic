import SwiftUI

struct LocalNeuralVoiceSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            Text("KOKORO ON-DEVICE VOICE")
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
                            Text("Kokoro Neural TTS")
                                .font(OpenMicTheme.Typography.headline)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                            Text("82M parameter model running on Apple Neural Engine via MLX. Natural speech in ~45ms. No cloud, no API key, fully offline.")
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

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kokoro v1 \u{2022} 82M params \u{2022} 24kHz \u{2022} 9 languages")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        Text("50 voices \u{2022} Non-autoregressive \u{2022} ~500MB memory")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()
                }
            }
        }
    }
}
