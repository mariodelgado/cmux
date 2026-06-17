actor AIRequestQueue {
    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run<T: Sendable>(_ operation: @escaping @Sendable () async -> T?) async -> T? {
        await waitForTurn()
        defer { finishTurn() }
        guard !Task.isCancelled else { return nil }
        return await operation()
    }

    private func waitForTurn() async {
        if !isRunning {
            isRunning = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func finishTurn() {
        guard !waiters.isEmpty else {
            isRunning = false
            return
        }
        let continuation = waiters.removeFirst()
        continuation.resume()
    }
}
