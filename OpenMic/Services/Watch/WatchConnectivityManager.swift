import Foundation
@preconcurrency import WatchConnectivity

private enum WatchMessageKey {
    static let action = "action"
    static let prompt = "prompt"
    static let history = "history"
    static let response = "response"
    static let error = "error"
    static let chatAction = "chat"
    static let tier = "tier"
    static let remainingMinutes = "remainingMinutes"
}

private struct WatchChatRequest: Sendable {
    let prompt: String
    let history: [ChatMessage]
}

private struct WatchChatResponse: Sendable {
    let text: String?
    let error: String?
}

private final class ReplyHandlerBox: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func reply(_ payload: [String: Any]) {
        handler(payload)
    }
}

final class WatchConnectivityManager: NSObject {
    private let session: WCSession?
    private let keychainManager: KeychainManager

    init(keychainManager: KeychainManager) {
        self.keychainManager = keychainManager
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()

        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Tier Sync

    func sendTierUpdate(tier: SubscriptionTier, remainingMinutes: Int = 0) {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext([
                WatchMessageKey.tier: tier.rawValue,
                WatchMessageKey.remainingMinutes: remainingMinutes,
            ])
        } catch {
            // Best effort — Watch will get context on next activation
        }
    }

    private static func decodeRequest(
        from message: [String: Any]
    ) -> WatchChatRequest? {
        guard
            let action = message[WatchMessageKey.action] as? String,
            action == WatchMessageKey.chatAction,
            let prompt = message[WatchMessageKey.prompt] as? String
        else {
            return nil
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return nil }

        let history = decodeHistory(from: message[WatchMessageKey.history])
        return WatchChatRequest(prompt: trimmedPrompt, history: history)
    }

    private static func decodeHistory(from value: Any?) -> [ChatMessage] {
        guard let raw = value as? [[String: String]] else { return [] }
        return raw.compactMap { entry in
            guard
                let roleRaw = entry["role"],
                let content = entry["content"],
                let role = MessageRole(rawValue: roleRaw)
            else {
                return nil
            }
            return ChatMessage(role: role, content: content)
        }
    }

    private static func resolveRequestedProviderType() -> AIProviderType {
        if let saved = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = AIProviderType(rawValue: saved) {
            return provider
        }
        return .openAI
    }

    private static func currentTier() -> SubscriptionTier {
        if let raw = UserDefaults.standard.string(forKey: "effectiveTier"),
           let tier = SubscriptionTier(rawValue: raw) {
            return tier
        }
        return .free
    }

    private static func processChat(
        _ request: WatchChatRequest,
        keychainManager: KeychainManager
    ) async -> WatchChatResponse {
        do {
            let requestedProvider = resolveRequestedProviderType()
            let tier = currentTier()
            let resolution = try await ProviderAccessPolicy.resolveProvider(
                requested: requestedProvider,
                tier: tier,
                surface: .watch,
                keychainManager: keychainManager
            )
            let providerType = resolution.effective
            print(
                "[ProviderAccess][\(ProviderSurface.watch.rawValue)] " +
                "requested=\(requestedProvider.rawValue) " +
                "effective=\(providerType.rawValue) " +
                "reason=\(resolution.fallbackReason?.rawValue ?? "none")"
            )

            let apiKey: String?
            if providerType.requiresAPIKey {
                apiKey = try? await keychainManager.getAPIKey(for: providerType)
            } else {
                apiKey = nil
            }
            let provider = try AIProviderFactory.create(
                type: providerType,
                apiKey: apiKey
            )

            var messages = request.history
            if messages.last?.content != request.prompt
                || messages.last?.role != .user {
                messages.append(
                    ChatMessage(role: .user, content: request.prompt)
                )
            }

            let stream = try await provider.streamChat(messages: messages)
            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
            }

            let trimmed = fullResponse.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !trimmed.isEmpty else {
                return WatchChatResponse(
                    text: nil,
                    error: "No response from provider."
                )
            }

            ProviderAccessPolicy.markProviderAsWorking(providerType)

            return WatchChatResponse(text: trimmed, error: nil)
        } catch let translated as AIProviderError {
            return WatchChatResponse(
                text: nil,
                error: translated.localizedDescription
            )
        } catch {
            return WatchChatResponse(
                text: nil,
                error: AIProviderError.translate(error).localizedDescription
            )
        }
    }

    private func processRequest(
        _ request: WatchChatRequest,
        reply: ReplyHandlerBox
    ) {
        let keychainManager = self.keychainManager
        WatchAsyncBridge.run(
            operation: {
                await Self.processChat(
                    request,
                    keychainManager: keychainManager
                )
            },
            completion: { response in
                let payload: [String: Any]
                if let text = response.text {
                    payload = [WatchMessageKey.response: text]
                } else {
                    payload = [
                        WatchMessageKey.error: response.error ?? "Unknown error"
                    ]
                }

                reply.reply(payload)
            }
        )
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        guard let request = Self.decodeRequest(from: message) else {
            replyHandler([WatchMessageKey.error: "Invalid request"])
            return
        }

        let reply = ReplyHandlerBox(replyHandler)
        processRequest(request, reply: reply)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
