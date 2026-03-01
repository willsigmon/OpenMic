import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class ConversationViewModel {
    private let appServices: AppServices
    private var voiceSession: (any VoiceSessionProtocol)?
    private var pipelineSession: PipelineVoiceSession? // For sendText/seedHistory
    private var startTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?
    private var activeUserBubbleID: UUID?
    private var activeAssistantBubbleID: UUID?

    private(set) var conversation: Conversation?
    private(set) var voiceState: VoiceSessionState = .idle
    private(set) var audioLevel: Float = 0
    private(set) var currentTranscript = ""
    private(set) var assistantTranscript = ""
    private(set) var errorMessage: String?
    private(set) var providerFallbackMessage: String?
    private(set) var activeProvider: AIProviderType
    private(set) var bubbles: [ConversationBubble] = []
    private(set) var isRealtimeSession = false

    var showUpgradePrompt = false
    var showPaywall = false

    var isListening: Bool { voiceState == .listening }
    var isProcessing: Bool { voiceState == .processing }
    var isSpeaking: Bool { voiceState == .speaking }
    var isActive: Bool { voiceState.isActive }

    var remainingMinutes: Int {
        appServices.usageTracker.remainingMinutes
    }

    var currentTier: SubscriptionTier {
        appServices.effectiveTier
    }

    init(appServices: AppServices) {
        self.appServices = appServices
        let storedProvider = UserDefaults.standard.string(forKey: "selectedProvider")
        self.activeProvider = AIProviderType(rawValue: storedProvider ?? "") ?? .openAI
    }

    // MARK: - Voice Control

    func toggleListening() {
        if isActive || voiceSession != nil || startTask != nil {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard startTask == nil, sendTask == nil, voiceSession == nil else { return }
        errorMessage = nil
        providerFallbackMessage = nil

        // Quota check
        let tier = appServices.effectiveTier
        if !appServices.usageTracker.canStartSession(tier: tier) {
            showUpgradePrompt = true
            return
        }

        startTask = Task { [weak self] in
            guard let self else { return }
            defer { startTask = nil }

            do {
                let session = try await buildSession()
                voiceSession = session

                if conversation == nil {
                    let persona = fetchActivePersona()
                    conversation = appServices.conversationStore.create(
                        providerType: activeProvider,
                        personaName: persona?.name ?? "Sigmon"
                    )
                    resetBubbleDraftState()
                    bubbles = []
                }

                observeStreams(session)

                // Seed conversation history for pipeline sessions
                if let pipeline = pipelineSession,
                   let conversation, !conversation.messages.isEmpty
                {
                    let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                    var history: [(role: MessageRole, content: String)] = []
                    if !systemPrompt.isEmpty {
                        history.append((.system, systemPrompt))
                    }
                    let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
                    for msg in sorted {
                        history.append((msg.messageRole, msg.content))
                    }
                    pipeline.seedHistory(history)
                }

                // Start usage tracking
                appServices.usageTracker.startSession()

                let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                try await session.start(systemPrompt: systemPrompt)
                ProviderAccessPolicy.markProviderAsWorking(activeProvider)
            } catch {
                if Task.isCancelled { return }
                voiceState = .idle
                errorMessage = error.localizedDescription
                tearDownObservers()
                voiceSession = nil
                pipelineSession = nil
            }
        }
    }

    func sendPrompt(_ text: String) {
        guard sendTask == nil else { return }
        errorMessage = nil
        providerFallbackMessage = nil

        // Quota check
        let tier = appServices.effectiveTier
        if !appServices.usageTracker.canStartSession(tier: tier) {
            showUpgradePrompt = true
            return
        }

        sendTask = Task { [weak self] in
            guard let self else { return }
            defer { sendTask = nil }

            do {
                startTask?.cancel()
                startTask = nil

                if voiceSession != nil {
                    await endCurrentSession()
                }

                let session = try await buildSession()
                voiceSession = session

                if conversation == nil {
                    let persona = fetchActivePersona()
                    conversation = appServices.conversationStore.create(
                        providerType: activeProvider,
                        personaName: persona?.name ?? "Sigmon"
                    )
                    resetBubbleDraftState()
                    bubbles = []
                }

                observeStreams(session)

                // Seed history for pipeline sessions
                if let pipeline = pipelineSession,
                   let conversation, !conversation.messages.isEmpty
                {
                    let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                    var history: [(role: MessageRole, content: String)] = []
                    if !systemPrompt.isEmpty {
                        history.append((.system, systemPrompt))
                    }
                    let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
                    for msg in sorted {
                        history.append((msg.messageRole, msg.content))
                    }
                    pipeline.seedHistory(history)
                }

                appServices.usageTracker.startSession()

                // sendText only works for pipeline sessions
                if let pipeline = pipelineSession {
                    let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                    await pipeline.sendText(text, systemPrompt: systemPrompt)
                    ProviderAccessPolicy.markProviderAsWorking(activeProvider)
                } else {
                    // For realtime sessions, start the session and the user will speak
                    let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                    try await session.start(systemPrompt: systemPrompt)
                    ProviderAccessPolicy.markProviderAsWorking(activeProvider)
                }
            } catch {
                if Task.isCancelled { return }
                voiceState = .idle
                errorMessage = error.localizedDescription
                tearDownObservers()
                voiceSession = nil
                pipelineSession = nil
            }
        }
    }

    func stopListening() {
        Task {
            startTask?.cancel()
            startTask = nil
            sendTask?.cancel()
            sendTask = nil
            await endCurrentSession()
            voiceState = .idle
            audioLevel = 0
        }
    }

    func interrupt() {
        Task {
            await voiceSession?.interrupt()
        }
    }

    // MARK: - Conversation Resume

    func loadConversation(_ conversation: Conversation) {
        stopListening()

        self.conversation = conversation
        activeProvider = conversation.provider
        providerFallbackMessage = nil

        let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        bubbles = sorted.map { msg in
            ConversationBubble(
                role: msg.messageRole,
                text: msg.content,
                isFinal: true,
                createdAt: msg.createdAt
            )
        }
        resetBubbleDraftState()
    }

    // MARK: - Session Builder

    private func buildSession() async throws -> any VoiceSessionProtocol {
        let requestedProvider = await resolveProviderType()
        let tier = appServices.effectiveTier
        let resolution = try await ProviderAccessPolicy.resolveProvider(
            requested: requestedProvider,
            tier: tier,
            surface: .iPhone,
            keychainManager: appServices.keychainManager
        )
        let providerType = resolution.effective
        activeProvider = providerType
        providerFallbackMessage = resolution.fallbackMessage

        print(
            "[ProviderAccess][\(ProviderSurface.iPhone.rawValue)] " +
            "requested=\(requestedProvider.rawValue) " +
            "effective=\(providerType.rawValue) " +
            "reason=\(resolution.fallbackReason?.rawValue ?? "none")"
        )

        // Use realtime session for premium tier with realtime-capable providers
        if tier.supportsRealtime,
           providerType.supportsRealtimeVoice,
           !tier.rawValue.isEmpty, // not BYOK using pipeline
           appServices.authManager.currentUserID != nil
        {
            isRealtimeSession = true
            pipelineSession = nil

            let authToken: String
            do {
                authToken = try await supabase.auth.session.accessToken
            } catch {
                throw AIProviderError.configurationMissing("Not authenticated for realtime")
            }

            return RealtimeVoiceSession(
                provider: providerType,
                proxyBaseURL: URL(string: "\(SupabaseConfig.url)/functions/v1/realtime-proxy")!,
                authToken: authToken,
                deviceID: appServices.authManager.effectiveDeviceID,
                voice: fetchActivePersona()?.openAIRealtimeVoice ?? "alloy"
            )
        }

        // Fall back to pipeline session (BYOK or standard tier)
        isRealtimeSession = false

        // For BYOK, use user's own API keys
        let apiKey: String?
        if tier == .byok {
            apiKey = try? await appServices.keychainManager.getAPIKey(for: providerType)
        } else {
            // For managed tiers, use proxy or built-in free model
            apiKey = try? await appServices.keychainManager.getAPIKey(for: providerType)
        }

        let aiProvider = try AIProviderFactory.create(
            type: providerType,
            apiKey: apiKey
        )

        let stt = SFSpeechSTT(paceProfile: .fast)
        let tts = try await buildTTSEngine()

        let pipeline = PipelineVoiceSession(
            sttEngine: stt,
            ttsEngine: tts,
            aiProvider: aiProvider
        )
        pipelineSession = pipeline
        return pipeline
    }

    private func buildTTSEngine() async throws -> TTSEngineProtocol {
        let engineType = TTSEngineType(
            rawValue: UserDefaults.standard.string(forKey: "ttsEngine") ?? "system"
        ) ?? .system

        switch engineType {
        case .system:
            let tts = SystemTTS()
            if let persona = fetchActivePersona(),
               let voiceId = persona.systemTTSVoice {
                tts.setVoice(identifier: voiceId)
            }
            return tts

        case .openAI:
            guard let key = try? await appServices.keychainManager.getAPIKey(for: .openAI),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let modelRaw = UserDefaults.standard.string(forKey: "openAITTSModel") ?? OpenAITTSModel.tts1.rawValue
            let model = OpenAITTSModel(rawValue: modelRaw) ?? .tts1

            let tts = OpenAITTS(apiKey: key, model: model)
            if let persona = fetchActivePersona(),
               let voice = persona.openAITTSVoice {
                tts.setVoice(voice)
            }
            return tts

        case .elevenLabs:
            guard let key = try? await appServices.keychainManager.getTTSKey(for: .elevenLabs),
                  !key.isEmpty else {
                let tts = SystemTTS()
                if let persona = fetchActivePersona(),
                   let voiceId = persona.systemTTSVoice {
                    tts.setVoice(identifier: voiceId)
                }
                return tts
            }

            let modelRaw = UserDefaults.standard.string(forKey: "elevenLabsModel") ?? ElevenLabsModel.flash.rawValue
            let model = ElevenLabsModel(rawValue: modelRaw) ?? .flash

            let tts = ElevenLabsTTS(
                apiKey: key,
                model: model
            )

            if let persona = fetchActivePersona(),
               let voiceId = persona.elevenLabsVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .humeAI:
            guard let key = try? await appServices.keychainManager.getTTSKey(for: .humeAI),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = HumeAITTS(apiKey: key)
            if let persona = fetchActivePersona(),
               let voiceId = persona.humeAIVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .googleCloud:
            guard let key = try? await appServices.keychainManager.getTTSKey(for: .googleCloud),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = GoogleCloudTTS(apiKey: key)
            if let persona = fetchActivePersona(),
               let voiceId = persona.googleCloudVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .cartesia:
            guard let key = try? await appServices.keychainManager.getTTSKey(for: .cartesia),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = CartesiaTTS(apiKey: key)
            if let persona = fetchActivePersona(),
               let voiceId = persona.cartesiaVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .amazonPolly:
            guard let accessKey = try? await appServices.keychainManager.getTTSKey(for: .amazonPolly),
                  let secretKey = try? await appServices.keychainManager.getTTSSecondaryKey(for: .amazonPolly),
                  !accessKey.isEmpty, !secretKey.isEmpty else {
                return SystemTTS()
            }

            let tts = AmazonPollyTTS(accessKey: accessKey, secretKey: secretKey)
            if let persona = fetchActivePersona(),
               let voiceId = persona.amazonPollyVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts

        case .deepgram:
            guard let key = try? await appServices.keychainManager.getTTSKey(for: .deepgram),
                  !key.isEmpty else {
                return SystemTTS()
            }

            let tts = DeepgramTTS(apiKey: key)
            if let persona = fetchActivePersona(),
               let voiceId = persona.deepgramVoiceID {
                tts.setVoice(id: voiceId)
            }
            return tts
        }
    }

    // MARK: - Stream Observers

    private func observeStreams(_ session: any VoiceSessionProtocol) {
        tearDownObservers()

        stateTask = Task { [weak self] in
            for await state in session.stateStream {
                guard let self, !Task.isCancelled else { break }
                self.voiceState = state
                if case .error(let msg) = state {
                    self.errorMessage = msg
                }
            }
        }

        transcriptTask = Task { [weak self] in
            for await transcript in session.transcriptStream {
                guard let self, !Task.isCancelled else { break }
                if transcript.role == .user {
                    self.currentTranscript = transcript.text
                    self.upsertBubble(transcript)
                    if transcript.isFinal, !transcript.text.isEmpty {
                        self.persistMessage(role: .user, content: transcript.text)
                    }
                } else if transcript.role == .assistant {
                    self.assistantTranscript = transcript.text
                    self.upsertBubble(transcript)
                    if transcript.isFinal, !transcript.text.isEmpty {
                        self.persistMessage(role: .assistant, content: transcript.text)
                    }
                }
            }
        }

        audioLevelTask = Task { [weak self] in
            for await level in session.audioLevelStream {
                guard let self, !Task.isCancelled else { break }
                self.audioLevel = level
            }
        }
    }

    private func tearDownObservers() {
        stateTask?.cancel()
        transcriptTask?.cancel()
        audioLevelTask?.cancel()
        stateTask = nil
        transcriptTask = nil
        audioLevelTask = nil
    }

    // MARK: - Session Lifecycle

    private func endCurrentSession() async {
        await voiceSession?.stop()
        tearDownObservers()

        // Track usage
        await appServices.usageTracker.endSession(
            provider: activeProvider.rawValue,
            tier: appServices.effectiveTier,
            deviceID: appServices.authManager.effectiveDeviceID,
            userID: appServices.authManager.currentUserID
        )

        voiceSession = nil
        pipelineSession = nil
    }

    // MARK: - Persistence

    private func persistMessage(role: MessageRole, content: String) {
        guard let conversation else { return }
        _ = appServices.conversationStore.addMessage(
            to: conversation,
            role: role,
            content: content
        )

        if role == .user, conversation.title == "New Conversation" {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = String(trimmed.prefix(60))
            appServices.conversationStore.updateTitle(conversation, title: title)
        }
    }

    // MARK: - Helpers

    private func fetchActivePersona() -> Persona? {
        let context = appServices.modelContainer.mainContext
        let descriptor = FetchDescriptor<Persona>(
            predicate: #Predicate { $0.isDefault == true }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func resolveProviderType() async -> AIProviderType {
        if let conversation {
            return conversation.provider
        }
        if let saved = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = AIProviderType(rawValue: saved) {
            return provider
        }
        for provider in AIProviderType.cloudProviders {
            if let hasKey = try? await appServices.keychainManager.hasAPIKey(for: provider),
               hasKey {
                return provider
            }
        }
        return .openAI
    }

    private func resetBubbleDraftState() {
        activeUserBubbleID = nil
        activeAssistantBubbleID = nil
    }

    private func upsertBubble(_ transcript: VoiceTranscript) {
        let trimmed = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let existingID: UUID?
        switch transcript.role {
        case .user:
            existingID = activeUserBubbleID
        case .assistant:
            existingID = activeAssistantBubbleID
        case .system:
            existingID = nil
        }

        if let existingID,
           let index = bubbles.firstIndex(where: { $0.id == existingID }) {
            bubbles[index] = ConversationBubble(
                id: existingID,
                role: transcript.role,
                text: trimmed,
                isFinal: transcript.isFinal,
                createdAt: bubbles[index].createdAt
            )
        } else {
            let bubble = ConversationBubble(
                role: transcript.role,
                text: trimmed,
                isFinal: transcript.isFinal
            )
            bubbles.append(bubble)
            switch transcript.role {
            case .user:
                activeUserBubbleID = bubble.id
            case .assistant:
                activeAssistantBubbleID = bubble.id
            case .system:
                break
            }
        }

        if transcript.isFinal {
            switch transcript.role {
            case .user:
                activeUserBubbleID = nil
            case .assistant:
                activeAssistantBubbleID = nil
            case .system:
                break
            }
        }

        if bubbles.count > 64 {
            bubbles.removeFirst(bubbles.count - 64)
        }
    }
}

struct ConversationBubble: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: MessageRole
    let text: String
    let isFinal: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        isFinal: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.isFinal = isFinal
        self.createdAt = createdAt
    }
}
