import Foundation
import WatchConnectivity

enum WatchBridgeError: LocalizedError {
    case unsupported
    case notReachable
    case invalidResponse
    case remoteError(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "Watch connectivity is not available."
        case .notReachable:
            "Your iPhone isn't reachable right now."
        case .invalidResponse:
            "Invalid response from iPhone."
        case .remoteError(let message):
            message
        }
    }
}

private enum WatchBridgeMessageKey {
    static let action = "action"
    static let prompt = "prompt"
    static let history = "history"
    static let response = "response"
    static let error = "error"
    static let chatAction = "chat"
}

final class WatchPhoneBridge: NSObject, @unchecked Sendable {
    static let shared = WatchPhoneBridge()

    private let session: WCSession?

    private override init() {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()

        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func ask(
        prompt: String,
        history: [[String: String]]
    ) async throws -> String {
        guard let session else { throw WatchBridgeError.unsupported }
        guard session.activationState == .activated else {
            session.activate()
            throw WatchBridgeError.notReachable
        }
        guard session.isReachable else { throw WatchBridgeError.notReachable }

        let payload: [String: Any] = [
            WatchBridgeMessageKey.action: WatchBridgeMessageKey.chatAction,
            WatchBridgeMessageKey.prompt: prompt,
            WatchBridgeMessageKey.history: history
        ]

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                payload,
                replyHandler: { response in
                    if let text = response[WatchBridgeMessageKey.response] as? String {
                        continuation.resume(returning: text)
                        return
                    }

                    if let errorMessage = response[WatchBridgeMessageKey.error] as? String {
                        continuation.resume(
                            throwing: WatchBridgeError.remoteError(errorMessage)
                        )
                        return
                    }

                    continuation.resume(throwing: WatchBridgeError.invalidResponse)
                },
                errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
}

extension WatchPhoneBridge: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    func sessionReachabilityDidChange(_ session: WCSession) {}
}
