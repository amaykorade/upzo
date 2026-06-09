#if os(iOS)
import AppIntents
import Foundation

/// Runs when the user stops a system AlarmKit alert — opens the app and records that a mission is owed.
public struct OpenWakeMissionIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Open wake-up mission"
    public static var description = IntentDescription("Opens Upzo to complete your wake-up mission.")
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID")
    public var alarmID: String

    public init() {
        self.alarmID = ""
    }

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        WakeDeliveryService.registerMissionOwedFromSystemAlarmTap(kitAlarmIDString: alarmID)
        return .result()
    }
}
#endif
