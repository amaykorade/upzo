#if os(iOS)
import Foundation

/// Coordinates permission requests so an alarm actually rings once the user saves it.
enum AlarmPermissions {
    typealias DeliveryMode = AppPermissions.DeliveryMode

    /// Requests alarms, notifications, and mission permissions (camera, mic, speech, photos).
    @MainActor
    @discardableResult
    static func ensureSchedulingPermissions() async -> DeliveryMode {
        await AppPermissions.ensureSchedulingPermissions()
    }

    @MainActor
    static func currentDeliveryMode() async -> DeliveryMode {
        await AppPermissions.currentDeliveryMode()
    }
}
#endif
