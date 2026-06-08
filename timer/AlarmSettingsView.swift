#if os(iOS)
import AlarmKit
import SwiftUI
import UIKit

struct AlarmSettingsView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @Environment(\.openURL) private var openURL

    @State private var alarmKitStatusText: String = ""
    @State private var alarmKitErrorText: String?
    @State private var isRequestingAlarmKit = false
    @State private var isSchedulingTest = false
    @State private var showNoAlarmForTestAlert = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(alarmKitStatusText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("System alarms", systemImage: "alarm.fill")
                }

                if let alarmKitErrorText {
                    Text(alarmKitErrorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    guard !isRequestingAlarmKit else { return }
                    isRequestingAlarmKit = true
                    alarmKitErrorText = nil
                    Task { @MainActor in
                        defer { isRequestingAlarmKit = false }
                        do {
                            let state = try await AlarmKitAlarmService.requestAuthorization()
                            alarmKitStatusText = AlarmKitAlarmService.settingsStatusLine(for: state)
                            await alarmStore.syncAlarmDeliveryToSystem()
                        } catch {
                            alarmKitStatusText = AlarmKitAlarmService.settingsStatusLine
                            alarmKitErrorText = error.localizedDescription
                        }
                    }
                } label: {
                    Label(isRequestingAlarmKit ? "Requesting…" : "Enable system alarms", systemImage: "clock.badge.checkmark")
                }
                .disabled(isRequestingAlarmKit)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open iOS Settings", systemImage: "gear")
                }
            } footer: {
                Text("Recommended: keep system alarms on. The app rings like Clock until you finish your mission; notifications are only a backup.")
            }

            Section {
                Button {
                    guard !isSchedulingTest else { return }
                    guard let alarm = alarmStore.alarms.first(where: { $0.isEnabled }) else {
                        showNoAlarmForTestAlert = true
                        return
                    }
                    isSchedulingTest = true
                    Task {
                        defer { isSchedulingTest = false }
                        let status = await AlarmNotificationManager.shared.authorizationStatus()
                        guard status == .authorized || status == .provisional else { return }
                        await AlarmNotificationManager.shared.scheduleTestNotification(
                            forAlarmId: alarm.id,
                            sound: alarm.alarmSound,
                            delay: 10
                        )
                    }
                } label: {
                    Label(isSchedulingTest ? "Scheduling…" : "Test alarm in 10 seconds", systemImage: "timer")
                }
                .disabled(isSchedulingTest)
            } footer: {
                Text("Schedules a one-time test using your next enabled alarm’s sound. Allow notifications first.")
            }
        }
        .navigationTitle("Alarm settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            alarmKitStatusText = AlarmKitAlarmService.settingsStatusLine
        }
        .task {
            for await state in AlarmManager.shared.authorizationUpdates {
                await MainActor.run {
                    alarmKitStatusText = AlarmKitAlarmService.settingsStatusLine(for: state)
                }
            }
        }
        .alert("No enabled alarm", isPresented: $showNoAlarmForTestAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create an alarm and turn it on, then try the test again.")
        }
    }
}
#endif
