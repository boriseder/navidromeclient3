import Foundation

// A thread-safe Debouncer using an Actor
actor Debouncer {
    private let delay: TimeInterval
    private var task: Task<Void, Never>?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func debounce(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                await action()
            }
        }
    }
}
