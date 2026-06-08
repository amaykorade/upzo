#if os(iOS)
import Foundation

/// Timing and IDs for the active wake chain: system rings + staggered notification sounds.
enum WakeChainPlanner {
    /// Number of follow-up system alarm rings after the first alert.
    static let systemRingCount = 10
    /// First follow-up system ring fires this many seconds after anchor.
    static let firstRingDelay: TimeInterval = 8
    /// Seconds between subsequent system rings after the first follow-up.
    static let ringInterval: TimeInterval = 30
    /// Notification fires this long before each corresponding system ring.
    static let notificationLeadBeforeRing: TimeInterval = 4

    /// Stable AlarmKit id for chain slot 1…`systemRingCount` (slot 1 matches legacy recatch id).
    static func chainSlotID(for sourceAlarmID: UUID, slot: Int) -> UUID {
        precondition((1 ... systemRingCount).contains(slot))
        var bytes = sourceAlarmID.uuid
        bytes.15 ^= UInt8(slot)
        return UUID(uuid: bytes)
    }

    static func allChainSlotIDs(for sourceAlarmID: UUID) -> [UUID] {
        (1 ... systemRingCount).map { chainSlotID(for: sourceAlarmID, slot: $0) }
    }

    /// System ring fire date for slot index 1…`systemRingCount`.
    static func systemRingDate(anchor: Date, slot: Int) -> Date {
        anchor.addingTimeInterval(firstRingDelay + Double(slot - 1) * ringInterval)
    }

    /// Notification fire date for gap index 0…`systemRingCount - 1` (each precedes its ring).
    static func notificationDate(anchor: Date, gapIndex: Int) -> Date {
        systemRingDate(anchor: anchor, slot: gapIndex + 1)
            .addingTimeInterval(-notificationLeadBeforeRing)
    }
}
#endif
