#if os(iOS)
import SwiftUI
import UserNotifications

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationPrefs: NotificationPreferencesStore
    @EnvironmentObject private var alarmStore: AlarmStore

    @State private var permissionStatusText = "Checking..."
    @State private var isRequestingPermission = false
    @State private var showEveningTimeSheet = false

    private var nextAlarm: Alarm? {
        alarmStore.alarms
            .filter(\.isEnabled)
            .min { a, b in
                let da = a.nextFireDate() ?? .distantFuture
                let db = b.nextFireDate() ?? .distantFuture
                return da < db
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    permissionCard
                    notificationTogglesCard
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .timerScreenBackground()
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showEveningTimeSheet) {
                EveningNudgeTimeSheet()
                    .environmentObject(notificationPrefs)
            }
            .task {
                await refreshPermissionStatus()
                await syncPreferenceNotifications()
            }
            .onChange(of: notificationPrefs.eveningNudgeEnabled) { _, _ in
                Task { await syncPreferenceNotifications() }
            }
            .onChange(of: notificationPrefs.eveningNudgeHour) { _, _ in
                Task { await syncPreferenceNotifications() }
            }
            .onChange(of: notificationPrefs.eveningNudgeMinute) { _, _ in
                Task { await syncPreferenceNotifications() }
            }
            .onChange(of: notificationPrefs.planRemindersEnabled) { _, _ in
                Task { await syncPreferenceNotifications() }
            }
            .onChange(of: notificationPrefs.finishSetupReminderEnabled) { _, _ in
                Task { await syncPreferenceNotifications() }
            }
            .tint(.primary)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Permission", systemImage: "bell.badge")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(permissionStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(permissionStatusColor)
            }

            if permissionStatusText == "Denied" || permissionStatusText == "Not determined yet" {
                Button {
                    requestPermission()
                } label: {
                    Label(isRequestingPermission ? "Requesting…" : "Enable notifications", systemImage: "bell.and.waves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(isRequestingPermission)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .timerCardBackground()
    }

    private var notificationTogglesCard: some View {
        VStack(spacing: 0) {
            eveningNudgeRow

            divider

            notificationToggleRow(
                title: "Plan reminders",
                subtitle: "Optional weekly reminder to review your wake plan. Off by default.",
                icon: "calendar",
                isOn: $notificationPrefs.planRemindersEnabled
            )

            divider

            notificationToggleRow(
                title: "Finish setup",
                subtitle: "Optional reminder if permissions or setup are still incomplete. Off by default.",
                icon: "checklist",
                isOn: $notificationPrefs.finishSetupReminderEnabled
            )

        }
        .timerCardBackground()
    }

    private var eveningNudgeRow: some View {
        VStack(spacing: 0) {
            notificationToggleRow(
                title: "Evening nudge",
                subtitle: notificationPrefs.eveningNudgeDescription(
                    missionTitle: nextAlarm?.missionType.title.lowercased()
                ),
                icon: "moon.stars.fill",
                isOn: $notificationPrefs.eveningNudgeEnabled
            )

            if notificationPrefs.eveningNudgeEnabled {
                Button {
                    showEveningTimeSheet = true
                } label: {
                    HStack {
                        Text("Delivered daily at \(notificationPrefs.eveningNudgeTimeDisplay)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Change")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 52)
    }

    private func notificationToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.toggleTint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var permissionStatusColor: Color {
        switch permissionStatusText {
        case "Enabled", "Provisional":
            return .green
        case "Denied":
            return .secondary
        default:
            return .secondary
        }
    }

    private func refreshPermissionStatus() async {
        let status = await AlarmNotificationManager.shared.authorizationStatus()
        permissionStatusText = statusDescription(status)
    }

    private func requestPermission() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        Task {
            defer { isRequestingPermission = false }
            let granted = await AlarmNotificationManager.shared.requestAuthorization()
            if granted {
                await alarmStore.syncAlarmDeliveryToSystem()
            }
            await refreshPermissionStatus()
            await syncPreferenceNotifications()
        }
    }

    private func syncPreferenceNotifications() async {
        await NotificationPreferencesScheduler.sync(
            preferences: notificationPrefs,
            alarms: alarmStore.alarms
        )
    }

    private func statusDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not determined yet"
        case .denied: return "Denied"
        case .authorized: return "Enabled"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
}

private struct EveningNudgeTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationPrefs: NotificationPreferencesStore

    @State private var pickerDate: Date

    init() {
        let store = NotificationPreferencesStore.shared
        var comps = DateComponents()
        comps.hour = store.eveningNudgeHour
        comps.minute = store.eveningNudgeMinute
        let date = Calendar.current.date(from: comps) ?? Date()
        _pickerDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Choose when you receive your evening reminder.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                DatePicker(
                    "Evening nudge time",
                    selection: $pickerDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .navigationTitle("Evening nudge time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: pickerDate)
                        notificationPrefs.saveEveningNudgeTime(
                            hour: parts.hour ?? 20,
                            minute: parts.minute ?? 0
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(.primary)
        }
        .presentationDetents([.medium, .fraction(0.48)])
        .presentationDragIndicator(.visible)
    }
}
#endif
