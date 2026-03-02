import SwiftUI

struct PermissionsStepView: View {
    let viewModel: OnboardingViewModel

    @State private var showContent = false

    private var allGranted: Bool {
        viewModel.hasMicPermission && viewModel.hasSpeechPermission
    }

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: OpenMicTheme.Spacing.xxl) {
                Spacer()

                // Hero icon
                GradientIcon(
                    systemName: allGranted ? "checkmark.shield.fill" : "shield.checkered",
                    gradient: allGranted ? OpenMicTheme.Gradients.listening : OpenMicTheme.Gradients.accent,
                    size: 72,
                    iconSize: 32,
                    glowColor: allGranted ? OpenMicTheme.Colors.glowGreen : OpenMicTheme.Colors.glowCyan,
                    isAnimated: allGranted
                )
                .opacity(showContent ? 1 : 0)

                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Text(allGranted ? "All Set!" : "Permissions")
                        .font(OpenMicTheme.Typography.title)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                        .contentTransition(.numericText())

                    Text(
                        allGranted
                            ? "Microphone and speech recognition are ready."
                            : "OpenMic needs microphone and speech recognition to have voice conversations."
                    )
                    .font(OpenMicTheme.Typography.body)
                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OpenMicTheme.Spacing.xl)
                }
                .opacity(showContent ? 1 : 0)

                // Permission cards
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    PermissionCard(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Capture your voice",
                        isGranted: viewModel.hasMicPermission
                    )

                    PermissionCard(
                        icon: "waveform",
                        title: "Speech Recognition",
                        description: "Transcribe your speech",
                        isGranted: viewModel.hasSpeechPermission
                    )
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Action buttons
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    if allGranted {
                        Button("Continue") {
                            viewModel.advance()
                        }
                        .buttonStyle(.openMicPrimary)
                    } else {
                        Button("Grant Permissions") {
                            viewModel.requestPermissions()
                        }
                        .buttonStyle(.openMicPrimary)

                        Button("Skip for Now") {
                            viewModel.advance()
                        }
                        .buttonStyle(.openMicGhost)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .animation(.default, value: allGranted)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
    }
}

// MARK: - Permission Card

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.md) {
                LayeredFeatureIcon(
                    systemName: icon,
                    color: isGranted ? OpenMicTheme.Colors.success : OpenMicTheme.Colors.accentGradientStart,
                    accentShape: isGranted ? .none : .ring
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

                // Status icon
                Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isGranted
                            ? OpenMicTheme.Colors.success
                            : OpenMicTheme.Colors.textTertiary
                    )
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .animation(.default, value: isGranted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isGranted ? "granted" : "not granted")")
        .accessibilityHint(description)
    }
}
