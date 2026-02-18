import Foundation
@testable import fedi_reader


private final class NotificationResultStore: @unchecked Sendable {
    private let lock = NSLock()
    private var result: ReadLaterSaveResult?

    func set(_ newValue: ReadLaterSaveResult?) {
        lock.lock()
        result = newValue
        lock.unlock()
    }

    func get() -> ReadLaterSaveResult? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

