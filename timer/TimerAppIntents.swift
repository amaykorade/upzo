#if os(iOS)
import AppIntents
import Foundation

struct OpenTimerAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Alarms"
    static var description = IntentDescription("Opens Timer to your alarms list.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "timer://alarms") else {
            throw IntentError.badURL
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

private enum IntentError: Error {
    case badURL
}
#else
import Foundation
#endif
