import CarPlay
import Speech
import AVFoundation

@MainActor
final class CarPlayVoiceController {

    // MARK: - Voice Control State Identifiers

    private enum StateID {
        static let idle         = "idle"
        static let listening    = "listening"
        static let processing   = "processing"
        static let speaking     = "speaking"
        static let noConfig     = "noConfig"
        static let noPermission = "noPermission"
        static let error        = "error"
    }

    private let interfaceController: CPInterfaceController
    private let voiceTemplate: CPVoiceControlTemplate

    private var session: PipelineVoiceSession?
    private var stateTask: Task<Void, Never>?
    private var buildTask: Task<Void, Never>?

    // Standalone dependencies (no AppServices access in CarPlay scene)
    private let keychainManager = KeychainManager()

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.voiceTemplate = Self.buildTemplate()

        pushTemplateAndStart()
    }

    // MARK: - Template Construction

    private static func buildTemplate() -> CPVoiceControlTemplate {
        let states = [
            buildState(id: StateID.idle, title: "Say something...", systemImage: "mic.circle.fill"),
            buildState(id: StateID.listening, title: "Listening...", systemImage: "waveform.circle.fill"),
            buildState(id: StateID.processing, title: "Thinking...", systemImage: "ellipsis.circle.fill"),
            buildState(id: StateID.speaking, title: "Speaking...", systemImage: "speaker.wave.2.circle.fill"),
            buildState(id: StateID.noConfig, title: "Setup needed", systemImage: "gear.badge.xmark"),
            buildState(id: StateID.noPermission, title: "Mic access needed", systemImage: "mic.slash.circle.fill"),
            buildState(id: StateID.error, title: "Something went wrong", systemImage: "exclamationmark.circle.fill"),
        ]
        return CPVoiceControlTemplate(voiceControlStates: states)
    }

    private static func buildState(
        id: String,
        title: String,
        systemImage: String
    ) -> CPVoiceControlState {
        let image = UIImage(systemName: systemImage) ?? UIImage()
        return CPVoiceControlState(
            identifier: id,
            titleVariants: [title],
            image: image,
            repeats: id == StateID.listening || id == StateID.processing || id == StateID.speaking
        )
    }

    // MARK: - Lifecycle

    private func pushTemplateAndStart() {
        interfaceController.pushTemplate(voiceTemplate, animated: true) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.beginSession()
            }
        }
    }

    private func beginSession() {
        buildTask = Task { [weak self] in
            guard let self else { return }
            await self.buildAndStartSession()
        }
    }

    private func buildAndStartSession() async {
        // Check permissions
        guard await checkPermissions() else {
            voiceTemplate.activateVoiceControlState(withIdentifier: StateID.noPermission)
            return
        }

        guard !Task.isCancelled else { return }

        let requestedProvider = resolveRequestedProviderType()
        let tier = currentTier()

        let resolution: ProviderResolutionResult
        do {
            resolution = try await ProviderAccessPolicy.resolveProvider(
                requested: requestedProvider,
                tier: tier,
                surface: .carPlay,
                keychainManager: keychainManager
            )
        } catch {
            voiceTemplate.activateVoiceControlState(withIdentifier: StateID.noConfig)
            return
        }

        let providerType = resolution.effective
        print(
            "[ProviderAccess][\(ProviderSurface.carPlay.rawValue)] " +
            "requested=\(requestedProvider.rawValue) " +
            "effective=\(providerType.rawValue) " +
            "reason=\(resolution.fallbackReason?.rawValue ?? "none")"
        )

        let apiKey: String?
        if providerType.requiresAPIKey {
            apiKey = try? await keychainManager.getAPIKey(for: providerType)
            guard let apiKey, !apiKey.isEmpty else {
                voiceTemplate.activateVoiceControlState(withIdentifier: StateID.noConfig)
                return
            }
        } else {
            apiKey = nil
        }

        guard !Task.isCancelled else { return }

        // Build AI provider
        let aiProvider: AIProvider
        do {
            aiProvider = try AIProviderFactory.create(type: providerType, apiKey: apiKey)
        } catch {
            voiceTemplate.activateVoiceControlState(withIdentifier: StateID.noConfig)
            return
        }

        // Build STT + TTS
        let stt = SFSpeechSTT(paceProfile: .fast)
        let tts = await buildTTSEngine()

        guard !Task.isCancelled else { return }

        // Configure audio for car
        do {
            try AudioSessionManager.shared.configureForCarPlay()
        } catch {
            voiceTemplate.activateVoiceControlState(withIdentifier: StateID.error)
            return
        }

        // Build pipeline session
        let systemPrompt = UserDefaults.standard.string(forKey: "carPlaySystemPrompt") ?? ""
        let pipeline = PipelineVoiceSession(
            sttEngine: stt,
            ttsEngine: tts,
            aiProvider: aiProvider,
            systemPrompt: systemPrompt
        )
        self.session = pipeline

        observeState(pipeline)

        guard !Task.isCancelled else { return }

        do {
            try await pipeline.start(systemPrompt: "")
            ProviderAccessPolicy.markProviderAsWorking(providerType)
        } catch {
            voiceTemplate.activateVoiceControlState(withIdentifier: StateID.error)
        }
    }

    // MARK: - State Observation

    private func observeState(_ session: PipelineVoiceSession) {
        stateTask?.cancel()
        stateTask = Task { [weak self] in
            for await state in session.stateStream {
                guard let self, !Task.isCancelled else { break }
                switch state {
                case .idle:
                    self.voiceTemplate.activateVoiceControlState(withIdentifier: StateID.idle)
                case .listening:
                    self.voiceTemplate.activateVoiceControlState(withIdentifier: StateID.listening)
                case .processing:
                    self.voiceTemplate.activateVoiceControlState(withIdentifier: StateID.processing)
                case .speaking:
                    self.voiceTemplate.activateVoiceControlState(withIdentifier: StateID.speaking)
                case .error:
                    self.voiceTemplate.activateVoiceControlState(withIdentifier: StateID.error)
                }
            }
        }
    }

    // MARK: - Permissions

    private func checkPermissions() async -> Bool {
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted { return false }
        } else if micStatus == .denied {
            return false
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            if !granted { return false }
        } else if speechStatus == .denied || speechStatus == .restricted {
            return false
        }

        return true
    }

    // MARK: - Provider Resolution

    private func resolveRequestedProviderType() -> AIProviderType {
        if let raw = UserDefaults.standard.string(forKey: "selectedProvider"),
           let type = AIProviderType(rawValue: raw) {
            return type
        }
        return .openAI
    }

    private func currentTier() -> SubscriptionTier {
        if let raw = UserDefaults.standard.string(forKey: "effectiveTier"),
           let tier = SubscriptionTier(rawValue: raw) {
            return tier
        }
        return .free
    }

    // MARK: - TTS Engine (mirrors ConversationViewModel.buildTTSEngine, standalone keychain)

    private func buildTTSEngine() async -> TTSEngineProtocol {
        let engineType = TTSEngineType(
            rawValue: UserDefaults.standard.string(forKey: "ttsEngine") ?? "system"
        ) ?? .system

        switch engineType {
        case .system:
            return SystemTTS()

        case .openAI:
            guard let key = try? await keychainManager.getAPIKey(for: .openAI),
                  !key.isEmpty else {
                return SystemTTS()
            }
            let modelRaw = UserDefaults.standard.string(forKey: "openAITTSModel") ?? OpenAITTSModel.tts1.rawValue
            let model = OpenAITTSModel(rawValue: modelRaw) ?? .tts1
            return OpenAITTS(apiKey: key, model: model)

        case .elevenLabs:
            guard let key = try? await keychainManager.getTTSKey(for: .elevenLabs),
                  !key.isEmpty else {
                return SystemTTS()
            }
            let modelRaw = UserDefaults.standard.string(forKey: "elevenLabsModel") ?? ElevenLabsModel.flash.rawValue
            let model = ElevenLabsModel(rawValue: modelRaw) ?? .flash
            return ElevenLabsTTS(apiKey: key, model: model)

        case .humeAI:
            guard let key = try? await keychainManager.getTTSKey(for: .humeAI),
                  !key.isEmpty else {
                return SystemTTS()
            }
            return HumeAITTS(apiKey: key)

        case .googleCloud:
            guard let key = try? await keychainManager.getTTSKey(for: .googleCloud),
                  !key.isEmpty else {
                return SystemTTS()
            }
            return GoogleCloudTTS(apiKey: key)

        case .cartesia:
            guard let key = try? await keychainManager.getTTSKey(for: .cartesia),
                  !key.isEmpty else {
                return SystemTTS()
            }
            return CartesiaTTS(apiKey: key)

        case .amazonPolly:
            guard let accessKey = try? await keychainManager.getTTSKey(for: .amazonPolly),
                  let secretKey = try? await keychainManager.getTTSSecondaryKey(for: .amazonPolly),
                  !accessKey.isEmpty, !secretKey.isEmpty else {
                return SystemTTS()
            }
            return AmazonPollyTTS(accessKey: accessKey, secretKey: secretKey)

        case .deepgram:
            guard let key = try? await keychainManager.getTTSKey(for: .deepgram),
                  !key.isEmpty else {
                return SystemTTS()
            }
            return DeepgramTTS(apiKey: key)
        }
    }

    // MARK: - Cleanup

    func cleanup() async {
        stateTask?.cancel()
        stateTask = nil
        buildTask?.cancel()
        buildTask = nil

        if let session {
            self.session = nil
            await session.stop()
        }

        try? AudioSessionManager.shared.deactivateCarPlay()
    }
}
