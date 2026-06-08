import Foundation
#if os(iOS)
import ActivityKit
import AlarmKit
import AudioToolbox
import AVFoundation
import UserNotifications
#endif

extension AlarmSound {
    /// Base name of a `.wav` in the app bundle, if any.
    var bundleResourceBaseName: String? {
        switch self {
        case .classic: "alarm_notification"
        case .pulse: "mission_alarm"
        case .chime: "alarm_chime"
        case .rise: "alarm_rise"
        case .beacon: "alarm_beacon"
        case .phoneRingtone: nil
        }
    }

    var bundleURL: URL? {
        guard let base = bundleResourceBaseName else { return nil }
        return Bundle.main.url(forResource: base, withExtension: "wav")
    }

    var usesSystemRingtone: Bool {
        self == .phoneRingtone
    }

#if os(iOS)
    var notificationSound: UNNotificationSound {
        if usesSystemRingtone {
            return .defaultRingtone
        }
        if let base = bundleResourceBaseName,
           Bundle.main.url(forResource: base, withExtension: "wav") != nil {
            return UNNotificationSound(named: UNNotificationSoundName("\(base).wav"))
        }
        return .defaultRingtone
    }

    /// Short clip for stacked local notifications — iOS often drops long (>30s) or ringtone sounds when the app is not running.
    var reliableNotificationSound: UNNotificationSound {
        if let base = bundleResourceBaseName,
           let url = Bundle.main.url(forResource: base, withExtension: "wav"),
           let duration = Self.wavDurationSeconds(url: url),
           duration <= 28 {
            return UNNotificationSound(named: UNNotificationSoundName("\(base).wav"))
        }
        if Bundle.main.url(forResource: "mission_alarm", withExtension: "wav") != nil {
            return UNNotificationSound(named: UNNotificationSoundName("mission_alarm.wav"))
        }
        return .default
    }

    private static func wavDurationSeconds(url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let rate = file.fileFormat.sampleRate
        guard rate > 0 else { return nil }
        return Double(file.length) / rate
    }

    var alarmKitAlertSound: ActivityKit.AlertConfiguration.AlertSound {
        if usesSystemRingtone {
            return .default
        }
        if let base = bundleResourceBaseName,
           Bundle.main.url(forResource: base, withExtension: "wav") != nil {
            return .named("\(base).wav")
        }
        return .default
    }
#endif
}

#if os(iOS)
/// Short preview when choosing a sound in the alarm editor.
@MainActor
final class AlarmSoundPreviewPlayer {
    static let shared = AlarmSoundPreviewPlayer()

    private var player: AVAudioPlayer?

    private init() {}

    func play(_ sound: AlarmSound) {
        stop()
        guard let url = sound.bundleURL else {
            if sound.usesSystemRingtone {
                AudioServicesPlayAlertSound(SystemSoundID(1005))
            }
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true, options: [])

        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = 0
        p.volume = 1.0
        p.prepareToPlay()
        guard p.play() else { return }
        player = p
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
#endif
