#if os(iOS)
import Foundation

struct PushupReadyLatch {
    static let latchDuration: TimeInterval = 8

    private var expiresAt: Date?

    func isActive(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt > now
    }

    mutating func refreshIfReady(_ ready: Bool, now: Date = Date()) {
        guard ready else { return }
        expiresAt = now.addingTimeInterval(Self.latchDuration)
    }

    mutating func clear() {
        expiresAt = nil
    }
}
#endif
