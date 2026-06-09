#if os(iOS)
import AlarmKit
import AVFoundation
import Foundation
import Photos
import Speech
import UserNotifications

/// Requests every permission needed for alarms and wake-up missions during first-time setup.
enum AppPermissions {
    struct SetupStatus: Equatable {
        var alarmKit: AlarmManager.AuthorizationState
        var notifications: UNAuthorizationStatus
        var camera: AVAuthorizationStatus
        var microphone: AVAuthorizationStatus
        var speech: SFSpeechRecognizerAuthorizationStatus
        var photoLibrary: PHAuthorizationStatus

        var alarmsReady: Bool { alarmKit == .authorized }

        var notificationsReady: Bool {
            notifications == .authorized || notifications == .provisional
        }
    }

    enum SetupItem: String, CaseIterable, Identifiable {
        case alarms
        case notifications
        case camera
        case microphone
        case speech
        case photos

        var id: String { rawValue }

        var title: String {
            switch self {
            case .alarms: "Alarms"
            case .notifications: "Notifications"
            case .camera: "Camera"
            case .microphone: "Microphone"
            case .speech: "Speech recognition"
            case .photos: "Photos"
            }
        }

        var systemImage: String {
            switch self {
            case .alarms: "alarm.fill"
            case .notifications: "bell.badge.fill"
            case .camera: "camera.fill"
            case .microphone: "mic.fill"
            case .speech: "waveform"
            case .photos: "photo.on.rectangle"
            }
        }

        var explanation: String {
            switch self {
            case .alarms:
                return "Play sound and show on screen even when a Focus is active — for alarms you create in this app."
            case .notifications:
                return "Backup alerts if a system alarm is missed."
            case .camera:
                return "Take photos for wake-up missions such as sky photos, object hunt, and pushups."
            case .microphone:
                return "Listen while you say your wake-up phrase."
            case .speech:
                return "Verify you said the correct phrase out loud."
            case .photos:
                return "Choose a photo from your library for photo missions."
            }
        }
    }

    /// Re-reads AlarmKit authorization (e.g. user enabled Alarms in Settings before opening the app).
    @MainActor
    static func syncAlarmKitAuthorizationState() async -> AlarmManager.AuthorizationState {
        let current = AlarmManager.shared.authorizationState
        guard current == .notDetermined else { return current }

        Task.detached(priority: .userInitiated) {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }

        for _ in 0 ..< 10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let state = AlarmManager.shared.authorizationState
            if state != .notDetermined { return state }
        }
        return AlarmManager.shared.authorizationState
    }

    @MainActor
    static func currentSetupStatus() async -> SetupStatus {
        let alarmKit = await syncAlarmKitAuthorizationState()
        return SetupStatus(
            alarmKit: alarmKit,
            notifications: await notificationStatus(),
            camera: AVCaptureDevice.authorizationStatus(for: .video),
            microphone: AVCaptureDevice.authorizationStatus(for: .audio),
            speech: SFSpeechRecognizer.authorizationStatus(),
            photoLibrary: PHPhotoLibrary.authorizationStatus(for: .readWrite)
        )
    }

    /// AlarmKit only — shows the system “schedule alarms and timers” sheet.
    @MainActor
    @discardableResult
    static func requestAlarmKitIfNeeded() async -> AlarmManager.AuthorizationState {
        let initial = await syncAlarmKitAuthorizationState()
        guard initial == .notDetermined else { return initial }

        // Present the system sheet without awaiting it directly (can stall on iPad after Allow).
        Task { @MainActor in
            _ = try? await AlarmManager.shared.requestAuthorization()
        }

        for _ in 0 ..< 40 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            let state = await syncAlarmKitAuthorizationState()
            if state != .notDetermined { return state }
        }
        return await syncAlarmKitAuthorizationState()
    }

    /// Notification-only fallback when AlarmKit is unavailable or the system prompt stalls.
    @MainActor
    @discardableResult
    static func requestNotificationsForScheduling() async -> Bool {
        let status = await notificationStatus()
        if status == .notDetermined {
            return await requestNotifications()
        }
        return status == .authorized || status == .provisional
    }

    /// Prompts for each permission type that is still undetermined (iOS shows one dialog at a time).
    @MainActor
    @discardableResult
    static func requestAllSetupPermissions() async -> SetupStatus {
        _ = await requestAlarmKitIfNeeded()

        let notif = await notificationStatus()
        if notif == .notDetermined {
            _ = await requestNotifications()
        }

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }

        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }

        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            _ = await requestSpeechRecognition()
        }

        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if photoStatus == .notDetermined {
            _ = await requestPhotoLibrary()
        }

        return await currentSetupStatus()
    }

    @MainActor
    static func isGranted(_ item: SetupItem, status: SetupStatus) -> Bool {
        switch item {
        case .alarms:
            return status.alarmsReady
        case .notifications:
            return status.notificationsReady
        case .camera:
            return status.camera == .authorized
        case .microphone:
            return status.microphone == .authorized
        case .speech:
            return status.speech == .authorized
        case .photos:
            switch status.photoLibrary {
            case .authorized, .limited:
                return true
            default:
                return false
            }
        }
    }

    @MainActor
    static func isDenied(_ item: SetupItem, status: SetupStatus) -> Bool {
        switch item {
        case .alarms:
            return status.alarmKit == .denied
        case .notifications:
            return status.notifications == .denied
        case .camera:
            return status.camera == .denied
        case .microphone:
            return status.microphone == .denied
        case .speech:
            return status.speech == .denied
        case .photos:
            return status.photoLibrary == .denied
        }
    }

    // MARK: - Scheduling (alarms + notifications)

    enum DeliveryMode {
        case alarmKit
        case notifications
        case none
    }

    @MainActor
    @discardableResult
    static func ensureSchedulingPermissions() async -> DeliveryMode {
        await requestAllSetupPermissions()
        return await currentDeliveryMode()
    }

    @MainActor
    static func currentDeliveryMode() async -> DeliveryMode {
        if AlarmManager.shared.authorizationState == .authorized {
            return .alarmKit
        }
        let status = await notificationStatus()
        if status == .authorized || status == .provisional {
            return .notifications
        }
        return .none
    }

    // MARK: - Private

    private static func notificationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private static func requestNotifications() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func requestSpeechRecognition() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func requestPhotoLibrary() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
#endif
