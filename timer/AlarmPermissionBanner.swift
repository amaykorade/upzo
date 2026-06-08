#if os(iOS)
import AlarmKit
import SwiftUI
import UIKit
import UserNotifications

/// Yellow warning shown on Alarms tab when at least one enabled alarm exists but neither
/// AlarmKit nor notifications can deliver it. Tapping requests permission, or sends the user to Settings.
struct AlarmPermissionBanner: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var alarmKitState: AlarmManager.AuthorizationState = .notDetermined
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        Group {
            if shouldShow {
                bannerContent
            } else {
                EmptyView()
            }
        }
        .task(id: alarmStore.alarms.count) {
            await refreshStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshStatus() }
            }
        }
        .task {
            for await state in AlarmManager.shared.authorizationUpdates {
                await MainActor.run { alarmKitState = state }
            }
        }
    }

    private var hasEnabledAlarm: Bool {
        alarmStore.alarms.contains(where: \.isEnabled)
    }

    private var shouldShow: Bool {
        guard hasEnabledAlarm else { return false }
        let alarmKitOK = alarmKitState == .authorized
        let notifOK = notificationStatus == .authorized || notificationStatus == .provisional
        return !alarmKitOK && !notifOK
    }

    private var bannerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your alarms won’t ring")
                        .font(.subheadline.weight(.semibold))
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await enableTapped() }
                } label: {
                    Text(isRequesting ? "Requesting…" : primaryButtonTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isRequesting)

                if alarmKitState == .denied || notificationStatus == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Text("iOS Settings")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private var detailText: String {
        if alarmKitState == .denied && (notificationStatus == .denied || notificationStatus == .notDetermined) {
            return "System alarms are turned off. Allow alarms or notifications in iOS Settings so your wake-ups can ring."
        }
        if notificationStatus == .denied {
            return "Notifications are off. Allow them in iOS Settings, or enable system alarms below."
        }
        return "Allow this app to schedule alarms and send notifications so your wake-ups can ring."
    }

    private var primaryButtonTitle: String {
        if alarmKitState == .denied && notificationStatus == .denied {
            return "Open iOS Settings"
        }
        return "Allow alarms"
    }

    private func enableTapped() async {
        if alarmKitState == .denied && notificationStatus == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
            return
        }
        isRequesting = true
        defer { isRequesting = false }
        _ = await AlarmPermissions.ensureSchedulingPermissions()
        await refreshStatus()
        await alarmStore.rescheduleNotifications()
    }

    private func refreshStatus() async {
        alarmKitState = AlarmManager.shared.authorizationState
        notificationStatus = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}
#endif
