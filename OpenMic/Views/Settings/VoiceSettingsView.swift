import AVFoundation
import SwiftUI
import SwiftData

struct VoiceSettingsView: View {
    @Environment(AppServices.self) private var appServices
    @AppStorage("ttsEngine") private var ttsEngine = TTSEngineType.system.rawValue
    @AppStorage("elevenLabsModel") private var elevenLabsModel = ElevenLabsModel.flash.rawValue
    @AppStorage("openAITTSModel") private var openAITTSModel = OpenAITTSModel.tts1.rawValue
    @AppStorage("audioOutputMode") private var audioOutputMode = AudioOutputMode.defaultMode.rawValue

    // Shared state for test voice
    @State private var isTesting = false
    @State private var testDiagnostic = ""

    private var selectedEngine: TTSEngineType {
        TTSEngineType(rawValue: ttsEngine) ?? .system
    }

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: OpenMicTheme.Spacing.lg) {
                    testVoiceSection
                    ttsEngineSection

                    switch selectedEngine {
                    case .system:
                        SystemVoiceSettingsSection()
                    case .localNeural:
                        LocalNeuralVoiceSettingsSection()
                    case .openAI:
                        OpenAIVoiceSettingsSection()
                    case .elevenLabs:
                        ElevenLabsVoiceSettingsSection()
                    case .humeAI:
                        HumeAIVoiceSettingsSection()
                    case .googleCloud:
                        GoogleCloudVoiceSettingsSection()
                    case .cartesia:
                        CartesiaVoiceSettingsSection()
                    case .amazonPolly:
                        AmazonPollyVoiceSettingsSection()
                    case .deepgram:
                        DeepgramVoiceSettingsSection()
                    }

                    audioOutputSection
                    vadSection
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.top, OpenMicTheme.Spacing.sm)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
            }
        }
        .navigationTitle("Voice & Audio")
    }

    // MARK: - Test Voice

    @ViewBuilder
    private var testVoiceSection: some View {
        Button {
            testVoice()
        } label: {
            GlassCard(cornerRadius: OpenMicTheme.Radius.lg, padding: OpenMicTheme.Spacing.md) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(
                                isTesting
                                    ? OpenMicTheme.Colors.speaking.opacity(0.2)
                                    : OpenMicTheme.Colors.accentGradientStart.opacity(0.15)
                            )
                            .frame(width: 44, height: 44)

                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(OpenMicTheme.Colors.speaking)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isTesting ? "Speaking..." : "Test Voice")
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text(testDiagnostic.isEmpty
                             ? "Hear how the current voice sounds"
                             : testDiagnostic)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(
                                testDiagnostic.isEmpty
                                    ? OpenMicTheme.Colors.textTertiary
                                    : OpenMicTheme.Colors.speaking
                            )
                    }

                    Spacer()

                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            isTesting
                                ? OpenMicTheme.Colors.speaking
                                : OpenMicTheme.Colors.textTertiary
                        )
                        .symbolEffect(.variableColor.iterative, isActive: isTesting)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isTesting)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isTesting)
    }

    // MARK: - TTS Engine Picker

    @ViewBuilder
    private var ttsEngineSection: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            Text("TEXT-TO-SPEECH ENGINE")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

            ForEach(TTSEngineType.allCases) { engine in
                TTSEngineCard(
                    engine: engine,
                    isSelected: engine.rawValue == ttsEngine
                ) {
                    withAnimation(OpenMicTheme.Animation.fast) {
                        ttsEngine = engine.rawValue
                    }
                }
            }
        }
    }

    // MARK: - Audio Output

    @ViewBuilder
    private var audioOutputSection: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            Text("AUDIO OUTPUT")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

            ForEach(AudioOutputMode.allCases) { mode in
                let isSelected = mode.rawValue == audioOutputMode
                Button {
                    withAnimation(OpenMicTheme.Animation.fast) {
                        audioOutputMode = mode.rawValue
                        AudioSessionManager.shared.setPreferredOutputMode(mode)
                    }
                } label: {
                    AudioOutputCard(mode: mode, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isSelected)
            }

            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxxs) {
                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        Text("Current route: \(AudioSessionManager.shared.currentOutputRouteName)")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                    }
                    Text(AudioSessionManager.shared.currentRouteSummary)
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - VAD

    @ViewBuilder
    private var vadSection: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
            Text("ADVANCED")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: "waveform.badge.mic",
                        color: OpenMicTheme.Colors.listening,
                        accentShape: .ring
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Detect Silence")
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text("Automatically ends recording when you stop speaking.")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Test Voice Action

    private func testVoice() {
        guard !isTesting else { return }
        isTesting = true
        testDiagnostic = ""
        Haptics.tap()

        let testText = "Hello! This is a voice test. How does this sound?"

        // Read current persona selections for voice IDs
        let persona = fetchActivePersona(from: appServices)

        Task {
            let engine: TTSEngineProtocol

            switch selectedEngine {
            case .system:
                testDiagnostic = "Testing System voice..."
                let tts = SystemTTS()
                if let voiceId = persona?.systemTTSVoice {
                    tts.setVoice(identifier: voiceId)
                }
                engine = tts

            case .localNeural:
                testDiagnostic = "Testing Local Neural voice..."
                engine = LocalNeuralTTS()

            case .openAI:
                testDiagnostic = "Testing OpenAI voice..."
                if let key = try? await appServices.keychainManager.getAPIKey(for: .openAI),
                   !key.isEmpty {
                    let modelRaw = openAITTSModel
                    let model = OpenAITTSModel(rawValue: modelRaw) ?? .tts1
                    let tts = OpenAITTS(apiKey: key, model: model)
                    if let voice = persona?.openAITTSVoice {
                        tts.setVoice(voice)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No OpenAI key \u{2014} falling back to System"
                    engine = SystemTTS()
                }

            case .elevenLabs:
                testDiagnostic = "Testing ElevenLabs voice..."
                if let key = try? await appServices.keychainManager.getElevenLabsKey(),
                   !key.isEmpty {
                    let modelRaw = elevenLabsModel
                    let model = ElevenLabsModel(rawValue: modelRaw) ?? .flash
                    let tts = ElevenLabsTTS(apiKey: key, model: model)
                    if let voiceId = persona?.elevenLabsVoiceID {
                        tts.setVoice(id: voiceId)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No ElevenLabs key \u{2014} falling back to System"
                    engine = SystemTTS()
                }

            case .humeAI:
                testDiagnostic = "Testing Hume AI voice..."
                if let key = try? await appServices.keychainManager.getHumeAIKey(),
                   !key.isEmpty {
                    let tts = HumeAITTS(apiKey: key)
                    if let voiceId = persona?.humeAIVoiceID {
                        tts.setVoice(id: voiceId)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No Hume AI key \u{2014} falling back to System"
                    engine = SystemTTS()
                }

            case .googleCloud:
                testDiagnostic = "Testing Google Cloud voice..."
                if let key = try? await appServices.keychainManager.getGoogleCloudKey(),
                   !key.isEmpty {
                    let tts = GoogleCloudTTS(apiKey: key)
                    if let voiceId = persona?.googleCloudVoiceID {
                        tts.setVoice(id: voiceId)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No Google Cloud key \u{2014} falling back to System"
                    engine = SystemTTS()
                }

            case .cartesia:
                testDiagnostic = "Testing Cartesia voice..."
                if let key = try? await appServices.keychainManager.getCartesiaKey(),
                   !key.isEmpty {
                    let tts = CartesiaTTS(apiKey: key)
                    if let voiceId = persona?.cartesiaVoiceID {
                        tts.setVoice(id: voiceId)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No Cartesia key \u{2014} falling back to System"
                    engine = SystemTTS()
                }

            case .amazonPolly:
                testDiagnostic = "Testing Amazon Polly voice..."
                if let accessKey = try? await appServices.keychainManager.getAmazonPollyAccessKey(),
                   let secretKey = try? await appServices.keychainManager.getAmazonPollySecretKey(),
                   !accessKey.isEmpty, !secretKey.isEmpty {
                    let tts = AmazonPollyTTS(accessKey: accessKey, secretKey: secretKey)
                    if let voiceId = persona?.amazonPollyVoiceID {
                        tts.setVoice(id: voiceId)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No Amazon Polly keys \u{2014} falling back to System"
                    engine = SystemTTS()
                }

            case .deepgram:
                testDiagnostic = "Testing Deepgram voice..."
                if let key = try? await appServices.keychainManager.getDeepgramKey(),
                   !key.isEmpty {
                    let tts = DeepgramTTS(apiKey: key)
                    if let voiceId = persona?.deepgramVoiceID {
                        tts.setVoice(id: voiceId)
                    }
                    engine = tts
                } else {
                    testDiagnostic = "No Deepgram key \u{2014} falling back to System"
                    engine = SystemTTS()
                }
            }

            await engine.speak(testText)
            testDiagnostic = ""
            isTesting = false
        }
    }
}

// MARK: - Audio Output Card

private struct AudioOutputCard: View {
    let mode: AudioOutputMode
    let isSelected: Bool

    private var icon: String {
        switch mode {
        case .automatic: "point.3.connected.trianglepath.dotted"
        case .speakerphone: "speaker.wave.3.fill"
        }
    }

    var body: some View {
        GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
            HStack(spacing: OpenMicTheme.Spacing.sm) {
                LayeredFeatureIcon(
                    systemName: icon,
                    color: isSelected
                        ? OpenMicTheme.Colors.accentGradientStart
                        : OpenMicTheme.Colors.textTertiary,
                    accentShape: .none
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(OpenMicTheme.Typography.headline)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Text(mode.subtitle)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Spacer()

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
}

// MARK: - TTS Engine Card

private struct TTSEngineCard: View {
    let engine: TTSEngineType
    let isSelected: Bool
    let action: () -> Void

    private var engineIcon: String {
        switch engine {
        case .system: "speaker.wave.2.fill"
        case .localNeural: "cpu.fill"
        case .openAI: "brain.head.profile.fill"
        case .elevenLabs: "waveform.circle.fill"
        case .humeAI: "heart.text.clipboard.fill"
        case .googleCloud: "cloud.fill"
        case .cartesia: "bolt.circle.fill"
        case .amazonPolly: "waveform.path"
        case .deepgram: "mic.badge.waveform"
        }
    }

    private var engineSubtitle: String {
        switch engine {
        case .system: "On-device neural voices \u{2014} free, no setup"
        case .localNeural: "Kokoro 82M neural voice \u{2014} offline, high quality"
        case .openAI: "Natural AI voices \u{2014} uses your OpenAI key"
        case .elevenLabs: "Ultra-realistic AI voices \u{2014} requires API key"
        case .humeAI: "Emotionally expressive voices \u{2014} requires API key"
        case .googleCloud: "300+ voices across multiple tiers \u{2014} BYOK"
        case .cartesia: "Ultra-low latency AI voices \u{2014} BYOK"
        case .amazonPolly: "AWS neural voices \u{2014} requires access + secret key"
        case .deepgram: "Aura-2 fast voices \u{2014} BYOK"
        }
    }

    var body: some View {
        Button(action: action) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: engineIcon,
                        color: isSelected
                            ? OpenMicTheme.Colors.accentGradientStart
                            : OpenMicTheme.Colors.textTertiary,
                        accentShape: .none
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.displayName)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text(engineSubtitle)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()

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
}
