import Foundation
import SwiftUI
import SwiftData
import os.log
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "ConversationViewModel")

struct ConversationSessionBuild {
    let voiceSession: any VoiceSessionProtocol
    let pipelineSession: PipelineVoiceSession?
    let provider: AIProviderType
    let providerFallbackMessage: String?
    let isRealtimeSession: Bool
}

typealias ConversationSessionBuilder = @MainActor () async throws -> ConversationSessionBuild

private struct DetachedConversationSession {
    let voiceSession: any VoiceSessionProtocol
    let usageSummary: UsageSessionSummary?
}

@Observable
@MainActor
final class ConversationViewModel {
    private let appServices: AppServices
    private let customSessionBuilder: ConversationSessionBuilder?
    private var voiceSession: (any VoiceSessionProtocol)?
    private var pipelineSession: PipelineVoiceSession? // For sendText/seedHistory
    private var startTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var startOperationID: UUID?
    private var sendOperationID: UUID?
    private var stateTask: Task<Void, Never>?
    private var transcriptTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?
    let bubbleBuffer = BubbleBuffer(maxBubbles: 64)

    private(set) var conversation: Conversation?
    private(set) var voiceState: VoiceSessionState = .idle
    private(set) var audioLevel: Float = 0
    private(set) var currentTranscript = ""
    private(set) var assistantTranscript = ""
    private(set) var errorMessage: String?
    private(set) var providerFallbackMessage: String?
    private(set) var activeProvider: AIProviderType
    private(set) var isRealtimeSession = false

    var bubbles: [ConversationBubble] { bubbleBuffer.bubbles }

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

    init(
        appServices: AppServices,
        sessionBuilder: ConversationSessionBuilder? = nil
    ) {
        self.appServices = appServices
        let storedProvider = UserDefaults.standard.string(forKey: "selectedProvider")
        self.activeProvider = AIProviderType(rawValue: storedProvider ?? "") ?? .openAI
        self.customSessionBuilder = sessionBuilder
    }

    // MARK: - Voice Control

    func toggleListening() {
        if isActive || voiceSession != nil || startTask != nil || sendTask != nil {
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

        let operationID = UUID()
        startOperationID = operationID
        startTask = Task { [weak self] in
            guard let self else { return }
            var pendingSession: (any VoiceSessionProtocol)?
            defer { finishStartOperation(operationID) }

            do {
                let build = try await makeSession()
                pendingSession = build.voiceSession

                guard isCurrentStartOperation(operationID) else {
                    await build.voiceSession.stop()
                    return
                }

                applySessionBuild(build)
                pendingSession = nil

                if conversation == nil {
                    let persona = fetchActivePersona()
                    conversation = try appServices.conversationStore.create(
                        providerType: build.provider,
                        personaName: persona?.name ?? AppConstants.Defaults.personaName
                    )
                    bubbleBuffer.removeAll()
                }

                observeStreams(build.voiceSession)

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

                let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                try await build.voiceSession.start(systemPrompt: systemPrompt)

                guard isCurrentStartOperation(operationID) else {
                    await build.voiceSession.stop()
                    return
                }

                appServices.usageTracker.startSession()
                ProviderAccessPolicy.markProviderAsWorking(activeProvider)

                // Start the Live Activity now that the session is confirmed live.
                let personaName = fetchActivePersona()?.name ?? AppConstants.Defaults.personaName
                let providerShortName = build.provider.shortName
                await liveActivityManager.startSession(
                    personaName: personaName,
                    providerName: providerShortName
                )
            } catch {
                if let pendingSession {
                    await pendingSession.stop()
                }
                if Task.isCancelled { return }

                guard isCurrentStartOperation(operationID) else { return }

                await voiceSession?.stop()
                voiceState = .idle
                errorMessage = error.localizedDescription
                tearDownObservers()
                voiceSession = nil
                pipelineSession = nil
                isRealtimeSession = false
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

        let operationID = UUID()
        sendOperationID = operationID
        sendTask = Task { [weak self] in
            guard let self else { return }
            var pendingSession: (any VoiceSessionProtocol)?
            defer { finishSendOperation(operationID) }
            var didStartUsage = false

            do {
                cancelStartOperation()

                if voiceSession != nil {
                    await endCurrentSession()
                }

                let build = try await makeSession()
                pendingSession = build.voiceSession

                guard isCurrentSendOperation(operationID) else {
                    await build.voiceSession.stop()
                    return
                }

                applySessionBuild(build)
                pendingSession = nil

                if conversation == nil {
                    let persona = fetchActivePersona()
                    conversation = try appServices.conversationStore.create(
                        providerType: build.provider,
                        personaName: persona?.name ?? AppConstants.Defaults.personaName
                    )
                    bubbleBuffer.removeAll()
                }

                observeStreams(build.voiceSession)

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

                // sendText only works for pipeline sessions
                if let pipeline = pipelineSession {
                    appServices.usageTracker.startSession()
                    didStartUsage = true
                    let persona = fetchActivePersona()
                    await liveActivityManager.startSession(
                        personaName: persona?.name ?? AppConstants.Defaults.personaName,
                        providerName: build.provider.shortName
                    )
                    let systemPrompt = persona?.systemPrompt ?? ""
                    try await pipeline.sendText(text, systemPrompt: systemPrompt)

                    guard isCurrentSendOperation(operationID) else {
                        return
                    }

                    ProviderAccessPolicy.markProviderAsWorking(activeProvider)
                } else {
                    // For realtime sessions, start the session and the user will speak
                    let systemPrompt = fetchActivePersona()?.systemPrompt ?? ""
                    try await build.voiceSession.start(systemPrompt: systemPrompt)

                    guard isCurrentSendOperation(operationID) else {
                        await build.voiceSession.stop()
                        return
                    }

                    appServices.usageTracker.startSession()
                    didStartUsage = true
                    ProviderAccessPolicy.markProviderAsWorking(activeProvider)
                    await liveActivityManager.startSession(
                        personaName: fetchActivePersona()?.name ?? AppConstants.Defaults.personaName,
                        providerName: build.provider.shortName
                    )
                }
            } catch {
                if let pendingSession {
                    await pendingSession.stop()
                }
                if Task.isCancelled { return }

                guard isCurrentSendOperation(operationID) else { return }

                await voiceSession?.stop()
                if didStartUsage {
                    await appServices.usageTracker.endSession(
                        provider: activeProvider.rawValue,
                        tier: appServices.effectiveTier,
                        deviceID: appServices.authManager.effectiveDeviceID,
                        userID: appServices.authManager.currentUserID
                    )
                }
                voiceState = .idle
                errorMessage = error.localizedDescription
                tearDownObservers()
                voiceSession = nil
                pipelineSession = nil
                isRealtimeSession = false
            }
        }
    }

    func stopListening() {
        cancelStartOperation()
        cancelSendOperation()
        let detachedSession = detachCurrentSession()
        voiceState = .idle
        audioLevel = 0

        Task { @MainActor [usageTracker = appServices.usageTracker] in
            guard let detachedSession else { return }
            await detachedSession.voiceSession.stop()
            guard let usageSummary = detachedSession.usageSummary else { return }
            await usageTracker.logFinishedSession(usageSummary)
        }
    }

    func interrupt() {
        Task { [weak self] in
            await self?.voiceSession?.interrupt()
        }
    }

    // MARK: - Provider Switching

    /// Available providers the user can switch to, with key readiness.
    func availableProviders() async -> [(provider: AIProviderType, ready: Bool)] {
        var results: [(provider: AIProviderType, ready: Bool)] = []
        for provider in AIProviderType.allCases where provider.isAvailable && provider.isRuntimeAvailable {
            if provider.requiresAPIKey {
                let hasKey = (try? await appServices.keychainManager.hasAPIKey(for: provider)) ?? false
                results.append((provider, hasKey))
            } else {
                results.append((provider, true))
            }
        }
        return results
    }

    /// Switch provider mid-conversation: tear down session, swap, insert marker, restart.
    func switchProvider(to newProvider: AIProviderType) {
        Task { [weak self] in
            await self?.switchProviderInternal(to: newProvider)
        }
    }

    // MARK: - Persona Switching

    /// Switch persona mid-conversation: tear down session, update default, insert marker, restart.
    func switchPersona(to persona: Persona) {
        Task { [weak self] in
            await self?.switchPersonaInternal(to: persona)
        }
    }

    // MARK: - Conversation Resume

    func loadConversation(_ conversation: Conversation) {
        Task { [weak self] in
            await self?.loadConversationInternal(conversation)
        }
    }

    // MARK: - Session Builder

    private func makeSession() async throws -> ConversationSessionBuild {
        if let customSessionBuilder {
            return try await customSessionBuilder()
        }
        return try await buildSession()
    }

    private func buildSession() async throws -> ConversationSessionBuild {
        let requestedProvider = await resolveProviderType()
        let tier = appServices.effectiveTier
        let resolution = try await ProviderAccessPolicy.resolveProvider(
            requested: requestedProvider,
            tier: tier,
            surface: .iPhone,
            keychainManager: appServices.keychainManager
        )
        let providerType = resolution.effective

        log.debug("[ProviderAccess][\(ProviderSurface.iPhone.rawValue, privacy: .public)] requested=\(requestedProvider.rawValue, privacy: .public) effective=\(providerType.rawValue, privacy: .public) reason=\(resolution.fallbackReason?.rawValue ?? "none", privacy: .public)")

        // Use realtime session for premium tier with realtime-capable providers
        if tier.supportsRealtime,
           tier != .byok,
           providerType.supportsRealtimeVoice,
           providerType.requiresAPIKey,
           appServices.authManager.currentUserID != nil
        {
            guard let proxyURL = SupabaseConfig.realtimeProxyURL else {
                throw AIProviderError.configurationMissing("Supabase realtime proxy URL not configured")
            }

            let authToken: String
            do {
                authToken = try await ManagedSessionTokenProvider.accessToken()
            } catch {
                throw AIProviderError.configurationMissing("Unable to start a managed session")
            }

            let session = try RealtimeVoiceSession(
                provider: providerType,
                proxyBaseURL: proxyURL,
                authToken: authToken,
                deviceID: appServices.authManager.effectiveDeviceID,
                voice: fetchActivePersona()?.openAIRealtimeVoice ?? "alloy"
            )
            return ConversationSessionBuild(
                voiceSession: session,
                pipelineSession: nil,
                provider: providerType,
                providerFallbackMessage: resolution.fallbackMessage,
                isRealtimeSession: true
            )
        }

        // Fall back to pipeline session (BYOK or standard tier)
        let aiProvider = try await AIProviderResolver.resolve(
            providerType: providerType,
            tier: tier,
            keychainManager: appServices.keychainManager
        )

        let stt = SFSpeechSTT(paceProfile: .fast)
        let tts = try await buildTTSEngine()

        let pipeline = PipelineVoiceSession(
            sttEngine: stt,
            ttsEngine: tts,
            aiProvider: aiProvider
        )
        return ConversationSessionBuild(
            voiceSession: pipeline,
            pipelineSession: pipeline,
            provider: providerType,
            providerFallbackMessage: resolution.fallbackMessage,
            isRealtimeSession: false
        )
    }

    private func buildTTSEngine() async throws -> TTSEngineProtocol {
        let engineType = TTSEngineType(
            rawValue: UserDefaults.standard.string(forKey: "ttsEngine") ?? "system"
        ) ?? .system

        return await TTSEngineBuilder.build(
            engine: engineType,
            keychainManager: appServices.keychainManager,
            persona: fetchActivePersona()
        )
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
                // Mirror every state transition into the Live Activity.
                let count = self.bubbles.filter { $0.isFinal }.count
                await self.liveActivityManager.updateState(state, messageCount: count)
            }
        }

        transcriptTask = Task { [weak self] in
            for await transcript in session.transcriptStream {
                guard let self, !Task.isCancelled else { break }
                let provider = self.activeProvider
                if transcript.role == .user {
                    self.currentTranscript = transcript.text
                    self.bubbleBuffer.upsert(transcript)
                    if transcript.isFinal, !transcript.text.isEmpty {
                        self.persistMessage(role: .user, content: transcript.text)
                    }
                } else if transcript.role == .assistant {
                    self.assistantTranscript = transcript.text
                    self.bubbleBuffer.upsert(transcript, provider: provider)
                    if transcript.isFinal, !transcript.text.isEmpty {
                        self.persistMessage(role: .assistant, content: transcript.text, provider: provider)
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

    private func applySessionBuild(_ build: ConversationSessionBuild) {
        voiceSession = build.voiceSession
        pipelineSession = build.pipelineSession
        activeProvider = build.provider
        providerFallbackMessage = build.providerFallbackMessage
        isRealtimeSession = build.isRealtimeSession
    }

    private func isCurrentStartOperation(_ operationID: UUID) -> Bool {
        startOperationID == operationID && !Task.isCancelled
    }

    private func isCurrentSendOperation(_ operationID: UUID) -> Bool {
        sendOperationID == operationID && !Task.isCancelled
    }

    private func finishStartOperation(_ operationID: UUID) {
        guard startOperationID == operationID else { return }
        startTask = nil
        startOperationID = nil
    }

    private func finishSendOperation(_ operationID: UUID) {
        guard sendOperationID == operationID else { return }
        sendTask = nil
        sendOperationID = nil
    }

    private func cancelStartOperation() {
        startTask?.cancel()
        startTask = nil
        startOperationID = nil
    }

    private func cancelSendOperation() {
        sendTask?.cancel()
        sendTask = nil
        sendOperationID = nil
    }

    private func detachCurrentSession() -> DetachedConversationSession? {
        guard let voiceSession else { return nil }
        tearDownObservers()
        let detachedSession = DetachedConversationSession(
            voiceSession: voiceSession,
            usageSummary: appServices.usageTracker.finishSession(
                provider: activeProvider.rawValue,
                tier: appServices.effectiveTier,
                deviceID: appServices.authManager.effectiveDeviceID,
                userID: appServices.authManager.currentUserID
            )
        )
        self.voiceSession = nil
        pipelineSession = nil
        isRealtimeSession = false
        return detachedSession
    }

    // MARK: - Session Lifecycle

    private func stopListeningInternal() async {
        cancelStartOperation()
        cancelSendOperation()
        await endCurrentSession()
        voiceState = .idle
        audioLevel = 0
    }

    private func switchProviderInternal(to newProvider: AIProviderType) async {
        guard newProvider != activeProvider else { return }

        let wasActive = isActive || voiceSession != nil || startTask != nil || sendTask != nil
        await stopListeningInternal()

        activeProvider = newProvider
        UserDefaults.standard.set(newProvider.rawValue, forKey: "selectedProvider")
        ToastManager.shared.showVoiceState("Now using \(newProvider.displayName)")

        let marker = ConversationBubble(
            role: .system,
            text: "Switched to \(newProvider.displayName)",
            isFinal: true
        )
        bubbleBuffer.append(marker)

        providerFallbackMessage = nil
        errorMessage = nil

        if wasActive {
            startListening()
        }
    }

    private func switchPersonaInternal(to persona: Persona) async {
        let currentPersona = fetchActivePersona()
        guard persona.id != currentPersona?.id else { return }

        let wasActive = isActive || voiceSession != nil || startTask != nil || sendTask != nil
        await stopListeningInternal()

        let context = appServices.modelContainer.mainContext
        if let current = currentPersona {
            current.isDefault = false
        }
        persona.isDefault = true
        try? context.save()

        if let conversation {
            conversation.personaName = persona.name
            conversation.updatedAt = Date()
            try? context.save()
        }

        let marker = ConversationBubble(
            role: .system,
            text: "Switched to \(persona.name)",
            isFinal: true
        )
        bubbleBuffer.append(marker)

        errorMessage = nil

        if wasActive {
            startListening()
        }
    }

    private func loadConversationInternal(_ conversation: Conversation) async {
        await stopListeningInternal()

        self.conversation = conversation
        activeProvider = conversation.provider
        providerFallbackMessage = nil

        let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        bubbleBuffer.replaceAll(sorted.map { msg in
            ConversationBubble(
                role: msg.messageRole,
                text: msg.content,
                isFinal: true,
                createdAt: msg.createdAt,
                provider: msg.provider
            )
        })
    }

    private func endCurrentSession() async {
        let sessionToStop = voiceSession
        let usageSummary = appServices.usageTracker.finishSession(
            provider: activeProvider.rawValue,
            tier: appServices.effectiveTier,
            deviceID: appServices.authManager.effectiveDeviceID,
            userID: appServices.authManager.currentUserID
        )

        await sessionToStop?.stop()
        tearDownObservers()

        voiceSession = nil
        pipelineSession = nil
        isRealtimeSession = false

        // End the Live Activity alongside the session.
        await liveActivityManager.endSession()

        guard let usageSummary else { return }
        Task { @MainActor [usageTracker = appServices.usageTracker] in
            await usageTracker.logFinishedSession(usageSummary)
        }
    }

    // MARK: - Persistence

    private func persistMessage(role: MessageRole, content: String, provider: AIProviderType? = nil) {
        guard let conversation else { return }
        do {
            _ = try appServices.conversationStore.addMessage(
                to: conversation,
                role: role,
                content: content,
                providerType: provider
            )

            if role == .user, conversation.title == AppConstants.Defaults.conversationTitle {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = String(trimmed.prefix(60))
                try appServices.conversationStore.updateTitle(conversation, title: title)
            }
        } catch {
            log.error("Failed to persist message: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Live Activity

    /// Convenience accessor that returns the live-activity manager when ActivityKit
    /// is available, or a no-op shim otherwise.
    private var liveActivityManager: any VoiceSessionActivityManaging {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            return VoiceSessionActivityManager.shared
        }
        #endif
        return NoOpVoiceSessionActivityManager.shared
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

}
