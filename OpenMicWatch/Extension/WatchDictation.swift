import Foundation
import WatchKit

enum WatchDictation {
    @MainActor
    static func captureText() async -> String? {
        await withCheckedContinuation { continuation in
            guard let controller = WKExtension.shared().visibleInterfaceController else {
                continuation.resume(returning: nil)
                return
            }

            controller.presentTextInputController(
                withSuggestions: nil,
                allowedInputMode: .plain
            ) { results in
                let text = results?.first as? String
                continuation.resume(
                    returning: text?.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )
            }
        }
    }
}
