#if os(iOS)
import AppIntents
import Foundation

/// Runs when the user stops a system AlarmKit alert — opens the app and records that a mission is owed.
struct OpenWakeMissionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open wake-up mission"
    static var description = IntentDescription("Opens Upzo to complete your wake-up mission.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        await WakeDeliveryService.registerMissionOwedFromSystemAlarmTap(kitAlarmIDString: alarmID)
        return .result()
    }
}
#endif
