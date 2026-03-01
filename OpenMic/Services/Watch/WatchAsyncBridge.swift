import Foundation

enum WatchAsyncBridge {
    static func run<Output: Sendable>(
        priority: TaskPriority? = .userInitiated,
        operation: @escaping @Sendable () async -> Output,
        completion: @escaping @Sendable (Output) -> Void
    ) {
        Task.detached(priority: priority) {
            let value = await operation()
            completion(value)
        }
    }
}
