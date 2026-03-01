import Foundation

struct WatchChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
final class WatchConversationViewModel: ObservableObject {
    @Published var draft = ""
    @Published var messages: [WatchChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let bridge = WatchPhoneBridge.shared
    private let maxHistoryCount = 10

    func sendDraft() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isLoading else { return }

        draft = ""
        errorMessage = nil
        messages.append(.init(role: .user, text: prompt))
        isLoading = true

        let history = bridgeHistory()

        Task {
            defer { isLoading = false }

            do {
                let response = try await bridge.ask(
                    prompt: prompt,
                    history: history
                )
                messages.append(.init(role: .assistant, text: response))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func dictateAndSend() {
        Task {
            guard let dictated = await WatchDictation.captureText(),
                  !dictated.isEmpty else {
                return
            }
            draft = dictated
            sendDraft()
        }
    }

    private func bridgeHistory() -> [[String: String]] {
        messages.suffix(maxHistoryCount).map { message in
            [
                "role": message.role.rawValue,
                "content": message.text
            ]
        }
    }
}
