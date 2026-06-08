#if os(iOS)
import AlarmKit
import AVFoundation
import Photos
import Speech
import SwiftUI
import UIKit

/// Full-screen setup after onboarding: AlarmKit permission first, then optional mission permissions.
struct SystemAlarmRequiredView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Binding var alarmKitState: AlarmManager.AuthorizationState
    var onPermissionsUpdated: () -> Void

    @State private var setupStatus = AppPermissions.SetupStatus(
        alarmKit: .notDetermined,
        notifications: .notDetermined,
        camera: .notDetermined,
        microphone: .notDetermined,
        speech: .notDetermined,
        photoLibrary: .notDetermined
    )
    @State private var isRequesting = false
    @State private var showAlarmPrimer = true
    @State private var requestWatchdog: Task<Void, Never>?

    private var alarmsDenied: Bool { alarmKitState == .denied }

    private var needsAlarmPrimer: Bool {
        showAlarmPrimer && alarmKitState == .notDetermined
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)

                    iconBlock

                    if needsAlarmPrimer {
                        alarmPermissionPrimer
                    } else {
                        generalPermissionsHeader
                        permissionsChecklist
                    }

                    if alarmsDenied && !needsAlarmPrimer {
                        settingsStepsCard
                    }

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
            }

            primaryActionBar
        }
        .timerScreenBackground()
        .task { await refreshSetupStatus() }
        .task {
            for await state in AlarmManager.shared.authorizationUpdates {
                guard state != .notDetermined else { continue }
                await applyAlarmKitState(state)
            }
        }
        .onAppear {
            Task {
                await refreshSetupStatus()
                await finishIfSchedulingReady()
            }
        }
        .onDisappear {
            requestWatchdog?.cancel()
            requestWatchdog = nil
        }
        .onChange(of: alarmKitState) { _, newState in
            guard newState != .notDetermined else { return }
            showAlarmPrimer = false
            isRequesting = false
            requestWatchdog?.cancel()
            requestWatchdog = nil
            Task { await finishIfSchedulingReady() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await refreshSetupStatus()
                await finishIfSchedulingReady()
            }
        }
    }

    // MARK: - Content

    private var iconBlock: some View {
        AppLogoView(size: 72, style: .appIcon)
    }

    private var alarmPermissionPrimer: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("Allow \(AppBrand.name) to schedule alarms and timers?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("This lets the app schedule alarms and timers that can play sound and appear on screen even when a Focus is active.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("We'll schedule alerts for alarms you create within our app.")
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            Text("Tap Continue — the next screen is Apple's permission request. Choose Allow so your wake-up alarms can ring reliably.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var generalPermissionsHeader: some View {
        VStack(spacing: 8) {
            Text(titleText)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(messageText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
    }

    private var titleText: String {
        alarmsDenied ? "Turn on access in Settings" : "One more step for missions"
    }

    private var messageText: String {
        if alarmsDenied {
            return "Alarms are required for wake-ups to ring properly. You can also enable camera, microphone, and other access for missions."
        }
        if alarmKitState == .authorized {
            return "Optional: allow notifications, camera, microphone, speech, and photos so every wake-up mission works the first time."
        }
        return "We'll also ask for notifications and mission permissions you can enable now or later in Settings."
    }

    private var permissionsChecklist: some View {
        VStack(spacing: 10) {
            ForEach(AppPermissions.SetupItem.allCases) { item in
                permissionRow(item)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func permissionRow(_ item: AppPermissions.SetupItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: statusIcon(for: item))
                .font(.body.weight(.semibold))
                .foregroundStyle(statusColor(for: item))
                .accessibilityLabel(statusLabel(for: item))
        }
    }

    private func statusIcon(for item: AppPermissions.SetupItem) -> String {
        if AppPermissions.isGranted(item, status: setupStatus) {
            return "checkmark.circle.fill"
        }
        if AppPermissions.isDenied(item, status: setupStatus) {
            return "xmark.circle.fill"
        }
        return "circle"
    }

    private func statusColor(for item: AppPermissions.SetupItem) -> Color {
        if AppPermissions.isGranted(item, status: setupStatus) {
            return .green
        }
        if AppPermissions.isDenied(item, status: setupStatus) {
            return .red
        }
        return .secondary.opacity(0.5)
    }

    private func statusLabel(for item: AppPermissions.SetupItem) -> String {
        if AppPermissions.isGranted(item, status: setupStatus) { return "Allowed" }
        if AppPermissions.isDenied(item, status: setupStatus) { return "Denied" }
        return "Not set"
    }

    private var settingsStepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to enable alarms")
                .font(.subheadline.weight(.semibold))
            Label("Open Settings below", systemImage: "1.circle.fill")
            Label("Tap Alarms (and Camera, Microphone, etc. as needed)", systemImage: "2.circle.fill")
            Label("Turn permissions on", systemImage: "3.circle.fill")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Action bar

    private var primaryActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await primaryAction() }
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Text(primaryButtonTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(isRequesting)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 16)

            if needsAlarmPrimer {
                Text("Continuing opens Apple's permission request.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
        }
        .background(.bar)
    }

    private var primaryButtonTitle: String {
        if needsAlarmPrimer { return "Continue" }
        if alarmsDenied { return "Open Settings" }
        if alarmKitState == .authorized {
            return "Continue"
        }
        return "Allow access"
    }

    // MARK: - Actions

    @MainActor
    private func refreshSetupStatus() async {
        setupStatus = await AppPermissions.currentSetupStatus()
        alarmKitState = setupStatus.alarmKit
        if alarmKitState != .notDetermined {
            showAlarmPrimer = false
            isRequesting = false
        }
    }

    private func primaryAction() async {
        if needsAlarmPrimer {
            await requestAlarmKitPermission()
            return
        }

        if alarmsDenied {
            openAppSettings()
            return
        }

        isRequesting = true
        setupStatus = await AppPermissions.requestAllSetupPermissions()
        await applyAlarmKitState(setupStatus.alarmKit)
        isRequesting = false
        await finishIfSchedulingReady()
    }

    /// Presents the system AlarmKit sheet (no dismiss / skip on the primer).
    @MainActor
    private func requestAlarmKitPermission() async {
        await refreshSetupStatus()
        if alarmKitState == .authorized {
            await finishIfSchedulingReady()
            return
        }

        isRequesting = true
        requestWatchdog?.cancel()
        requestWatchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            isRequesting = false
            await refreshSetupStatus()
            if alarmKitState == .notDetermined {
                showAlarmPrimer = false
            }
            await finishIfSchedulingReady()
        }

        let state = await AppPermissions.requestAlarmKitIfNeeded()
        requestWatchdog?.cancel()
        requestWatchdog = nil
        await applyAlarmKitState(state)
        isRequesting = false
    }

    @MainActor
    private func applyAlarmKitState(_ state: AlarmManager.AuthorizationState) async {
        alarmKitState = state
        setupStatus = await AppPermissions.currentSetupStatus()
        if state != .notDetermined {
            showAlarmPrimer = false
            isRequesting = false
        }
        await finishIfSchedulingReady()
    }

    @MainActor
    private func finishIfSchedulingReady() async {
        guard await AppSchedulingAccess.canDeliverAlarms() else { return }
        if alarmKitState == .authorized {
            await alarmStore.rescheduleNotifications()
        }
        onPermissionsUpdated()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
#endif
