#if os(iOS)
import AlarmKit
import SwiftUI
import UIKit

struct AlarmSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appSettings: AlarmAppSettingsStore
    @EnvironmentObject private var alarmStore: AlarmStore

    @State private var showGoalTimeSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    goalWakeTimeCard

                    togglesCard

                    wakeDeliveryInfoCard

                    alarmVolumeCard

                    missionVerificationSection

                    NavigationLink {
                        AlarmSettingsView()
                            .environmentObject(alarmStore)
                    } label: {
                        Label {
                            Text("System alarms & test")
                                .font(.subheadline.weight(.semibold))
                        } icon: {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .timerCardBackground()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .timerScreenBackground()
            .navigationTitle("Alarm settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showGoalTimeSheet) {
                GoalWakeTimeSheet()
                    .environmentObject(appSettings)
            }
            .tint(.primary)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var goalWakeTimeCard: some View {
        Button {
            showGoalTimeSheet = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal wake time")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(
                        appSettings.hasGoalWakeTime
                            ? appSettings.goalWakeTimeDisplay
                            : "Set your target wake time"
                    )
                    .font(appSettings.hasGoalWakeTime ? .title3.weight(.semibold).monospacedDigit() : .subheadline)
                    .foregroundStyle(appSettings.hasGoalWakeTime ? .primary : .secondary)
                    Text("Track progress against your goal in Insights.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .timerCardBackground()
        }
        .buttonStyle(.plain)
    }

    private var wakeDeliveryInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How wake-up rings", systemImage: "bell.and.waves.left.and.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if AlarmKitAlarmService.isAuthorized {
                Text("Uses iPhone system alarms (like Clock). Finish your mission to stop. If you dismiss without finishing, the system alarm rings again about every 30 seconds for up to 10 minutes; notifications are backup only.")
            } else {
                Text("System alarms are off. Wake-ups use notifications only (shorter sounds, more repeat pings for ~7 minutes). Turn on system alarms below for the best experience.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .timerCardBackground()
    }

    private var togglesCard: some View {
        VStack(spacing: 0) {
            settingsToggleRow(
                title: "Vibration",
                subtitle: "Haptic pulses during the wake-up mission",
                icon: "iphone.radiowaves.left.and.right",
                isOn: $appSettings.vibrationEnabled
            )
            Divider().padding(.leading, 52)
            settingsToggleRow(
                title: "Alarm during mission",
                subtitle: "Keep alarm audio playing until the mission is done",
                icon: "speaker.wave.2.fill",
                isOn: $appSettings.alarmDuringMissionEnabled
            )
            Divider().padding(.leading, 52)
            settingsToggleRow(
                title: "Snooze",
                subtitle: "Allow one 5-minute snooze per alarm",
                icon: "clock.arrow.circlepath",
                isOn: $appSettings.snoozeEnabled
            )
        }
        .timerCardBackground()
    }

    private func settingsToggleRow(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
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

    private var alarmVolumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alarm volume")
                .font(.subheadline.weight(.semibold))

            Text("This uses your iPhone alarm volume. Adjust it in Settings → Sounds & Haptics → Ringer and Alerts.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Label("Open Apple Settings", systemImage: "gear")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .timerCardBackground()
    }

    private var missionVerificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mission verification")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(MissionVerificationLevel.allCases) { level in
                verificationOption(level)
            }
        }
    }

    private func verificationOption(_ level: MissionVerificationLevel) -> some View {
        let selected = appSettings.missionVerificationLevel == level

        return Button {
            appSettings.missionVerificationLevel = level
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.primary : Color.secondary.opacity(0.45))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(level.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(level.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.06) : AppTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(selected ? Color.primary.opacity(0.18) : AppTheme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct GoalWakeTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AlarmAppSettingsStore

    @State private var pickerDate: Date

    init() {
        let store = AlarmAppSettingsStore.shared
        var comps = DateComponents()
        comps.hour = store.goalWakeHour
        comps.minute = store.goalWakeMinute
        let date = Calendar.current.date(from: comps) ?? Date()
        _pickerDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Set your target wake time to track your progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                DatePicker(
                    "Goal wake time",
                    selection: $pickerDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .navigationTitle("Goal wake time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save goal time") {
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: pickerDate)
                        appSettings.saveGoalWakeTime(
                            hour: parts.hour ?? 7,
                            minute: parts.minute ?? 0
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(.primary)
        }
        .presentationDetents([.medium, .fraction(0.52)])
        .presentationDragIndicator(.visible)
    }
}
#endif
