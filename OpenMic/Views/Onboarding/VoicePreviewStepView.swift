import SwiftUI
import AVFoundation

struct VoicePreviewStepView: View {
    let viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var playingVoice: VoicePreviewTier?
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: OpenMicTheme.Spacing.xxl) {
                Spacer()

                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Text("Hear the Difference")
                        .font(OpenMicTheme.Typography.heroTitle)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Text("Real AI voice makes conversations natural")
                        .font(OpenMicTheme.Typography.body)
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)

                // Voice comparison cards
                VStack(spacing: OpenMicTheme.Spacing.md) {
                    VoicePreviewCard(
                        tier: .free,
                        label: "Free Voice",
                        description: "On-device system TTS",
                        isPlaying: playingVoice == .free,
                        onPlay: { togglePlayback(.free) }
                    )

                    VoicePreviewCard(
                        tier: .standard,
                        label: "Standard",
                        description: "OpenAI TTS — natural speech",
                        isPlaying: playingVoice == .standard,
                        onPlay: { togglePlayback(.standard) },
                        badge: "Popular"
                    )

                    VoicePreviewCard(
                        tier: .premium,
                        label: "Premium",
                        description: "Realtime AI — emotional, instant",
                        isPlaying: playingVoice == .premium,
                        onPlay: { togglePlayback(.premium) }
                    )
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Action buttons
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Button("Start Free") {
                        Haptics.tap()
                        viewModel.advance()
                    }
                    .buttonStyle(.carChatPrimary)

                    Button("View Plans") {
                        Haptics.tap()
                        viewModel.showPaywall = true
                    }
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(OpenMicTheme.Animation.smooth.delay(0.2)) {
                showContent = true
            }
        }
        .onDisappear {
            audioPlayer?.stop()
        }
    }

    private func togglePlayback(_ tier: VoicePreviewTier) {
        Haptics.tap()
        if playingVoice == tier {
            audioPlayer?.stop()
            playingVoice = nil
            return
        }

        audioPlayer?.stop()
        playingVoice = tier

        // Play pre-recorded sample from bundle
        guard let url = Bundle.main.url(
            forResource: tier.sampleFileName,
            withExtension: "m4a"
        ) else {
            playingVoice = nil
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = nil
            audioPlayer?.play()

            // Auto-stop when done
            Task {
                guard let duration = audioPlayer?.duration else { return }
                try? await Task.sleep(for: .seconds(duration + 0.1))
                if playingVoice == tier {
                    playingVoice = nil
                }
            }
        } catch {
            playingVoice = nil
        }
    }
}

// MARK: - Voice Preview Card

private struct VoicePreviewCard: View {
    let tier: VoicePreviewTier
    let label: String
    let description: String
    let isPlaying: Bool
    let onPlay: () -> Void
    var badge: String? = nil

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
            HStack(spacing: OpenMicTheme.Spacing.md) {
                // Play button
                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(tier.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(tier.accentColor)
                    }
                }
                .accessibilityLabel(isPlaying ? "Stop \(label) preview" : "Play \(label) preview")

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(label)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tier.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(description)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Spacer()

                // Audio waveform indicator
                if isPlaying {
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(tier.accentColor)
                                .frame(width: 3, height: CGFloat.random(in: 8...20))
                                .animation(
                                    .easeInOut(duration: 0.3)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.1),
                                    value: isPlaying
                                )
                        }
                    }
                    .frame(width: 20)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md)
                .stroke(isPlaying ? tier.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Types

enum VoicePreviewTier {
    case free, standard, premium

    var sampleFileName: String {
        switch self {
        case .free: "voice_sample_free"
        case .standard: "voice_sample_standard"
        case .premium: "voice_sample_premium"
        }
    }

    var accentColor: Color {
        switch self {
        case .free: OpenMicTheme.Colors.textTertiary
        case .standard: OpenMicTheme.Colors.accentGradientStart
        case .premium: OpenMicTheme.Colors.speaking
        }
    }
}
