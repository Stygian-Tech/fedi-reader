import Foundation

actor SharedTestResourceGate {
    static let shared = SharedTestResourceGate()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    static func withExclusiveAccess<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let gate = SharedTestResourceGate.shared
        await gate.acquire()

        do {
            let result = try await operation()
            await gate.release()
            return result
        } catch {
            await gate.release()
            throw error
        }
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard let nextWaiter = waiters.first else {
            isLocked = false
            return
        }

        waiters.removeFirst()
        nextWaiter.resume()
    }
}
