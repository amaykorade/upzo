#if os(iOS)
import UIKit
#endif
import SwiftUI

/// Shared metrics and fonts so the alarm sheet reads as one coherent form.
private enum AlarmEditorStyle {
    static let fieldPadding: CGFloat = 16
    static let blockSpacing: CGFloat = 16
    static let fieldCorner: CGFloat = 12

    static let body: Font = .body
    static let bodyEmphasis: Font = .body.weight(.semibold)
    static let sectionCaption: Font = .subheadline.weight(.semibold)
    static let timeDisplay: Font = .title2.weight(.semibold)
    static let segment: Font = .body.weight(.semibold)
    static let weekdayChip: Font = .subheadline.weight(.semibold)
}

struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var alarmStore: AlarmStore

    private let editingAlarmID: UUID?

    @State private var alarmTitle: String
    @State private var pickerHour: Int
    @State private var pickerMinute: Int
    @State private var dateForPicker: Date
    @State private var showTimeSheet = false
    @State private var showMissionPicker = false
    @State private var showSoundPicker = false
    @State private var scheduleMode: AlarmScheduleMode
    @State private var repeatDays: Set<Weekday>
    @State private var missionType: MissionType
    @State private var alarmSound: AlarmSound
    @State private var isEnabled: Bool
    @State private var showDeleteConfirmation = false

    init(editingAlarmID: UUID?) {
        self.editingAlarmID = editingAlarmID

        _alarmTitle = State(initialValue: "")
        _pickerHour = State(initialValue: 7)
        _pickerMinute = State(initialValue: 0)
        _dateForPicker = State(initialValue: Alarm.pickerDate(hour: 7, minute: 0))
        _scheduleMode = State(initialValue: .scheduled)
        _missionType = State(initialValue: .shake)
        _alarmSound = State(initialValue: .classic)
        _isEnabled = State(initialValue: true)
        _repeatDays = State(initialValue: [.monday])
    }

    private var isEditingExistingAlarm: Bool {
        editingAlarmID != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AlarmEditorStyle.blockSpacing) {
                    nameField

                    timeField

                    scheduleModePicker

                    if scheduleMode == .scheduled {
                        repeatSection
                    }

                    missionField

                    soundField

                    alarmOnRow

                    if isEditingExistingAlarm {
                        deleteAlarmButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(editorScrollBackground)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveButtonBar
            }
            .alert("Delete alarm?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAndDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This alarm will be removed and will no longer ring.")
            }
            .navigationTitle(editorNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    PickerSheetCloseButton { dismiss() }
                }
            }
            .sheet(isPresented: $showTimeSheet) {
                AlarmTimePickerSheet(date: $dateForPicker)
                    .presentationDetents([.medium, .fraction(0.42)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMissionPicker) {
                MissionPickerSheet(selection: $missionType)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSoundPicker) {
                SoundPickerSheet(selection: $alarmSound)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                loadFromStore()
            }
            .onChange(of: dateForPicker) { _, newValue in
                let time = Alarm.pickerTime(from: newValue)
                pickerHour = time.hour
                pickerMinute = time.minute
            }
        }
    }

    /// Always loads the latest alarm from the store (list and editor stay in sync).
    private func loadFromStore() {
        guard let id = editingAlarmID,
              let alarm = alarmStore.alarm(id: id)
        else { return }

        alarmTitle = alarm.title
        pickerHour = alarm.hour
        pickerMinute = alarm.minute
        dateForPicker = Alarm.pickerDate(hour: alarm.hour, minute: alarm.minute)
        scheduleMode = alarm.scheduleMode
        missionType = alarm.missionType
        alarmSound = alarm.alarmSound
        isEnabled = alarm.isEnabled
        repeatDays = Set(alarm.repeatDays.isEmpty ? [Weekday.monday] : alarm.repeatDays)
    }

    private var editorNavigationTitle: String {
        isEditingExistingAlarm ? "Edit alarm" : "New alarm"
    }

    private var nameField: some View {
        TextField("Morning workout", text: $alarmTitle)
            .font(AlarmEditorStyle.body)
            .textFieldStyle(.plain)
            .padding(AlarmEditorStyle.fieldPadding)
            .background(fieldBackground)
            .overlay(fieldOutline)
            .accessibilityLabel("Alarm name")
    }

    private var timeField: some View {
        Button {
            showTimeSheet = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("Alarm time")
                    .font(AlarmEditorStyle.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(Alarm.formattedTime(hour: pickerHour, minute: pickerMinute))
                    .font(AlarmEditorStyle.timeDisplay)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AlarmEditorStyle.body)
                    .foregroundStyle(.tertiary)
            }
            .padding(AlarmEditorStyle.fieldPadding)
            .background(fieldBackground)
            .overlay(fieldOutline)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change time, currently \(Alarm.formattedTime(hour: pickerHour, minute: pickerMinute))")
    }

    private var scheduleModePicker: some View {
        Picker("Schedule mode", selection: $scheduleMode) {
            Text("Schedule")
                .font(AlarmEditorStyle.segment)
                .tag(AlarmScheduleMode.scheduled)
            Text("One time")
                .font(AlarmEditorStyle.segment)
                .tag(AlarmScheduleMode.oneTime)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
#if os(iOS)
        .controlSize(.large)
#endif
        .padding(.vertical, 4)
        .accessibilityLabel("Schedule or one time")
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat on")
                .font(AlarmEditorStyle.sectionCaption)
                .foregroundStyle(.secondary)
            WeekdayRowPicker(selectedDays: $repeatDays)
        }
        .padding(AlarmEditorStyle.fieldPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fieldBackground)
        .overlay(fieldOutline)
    }

    private var missionField: some View {
        Button {
            showMissionPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mission")
                    .font(AlarmEditorStyle.sectionCaption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: missionType.systemImageName)
                        .foregroundStyle(.secondary)
                    Text(missionType.title)
                        .font(AlarmEditorStyle.body)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(AlarmEditorStyle.fieldPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground)
            .overlay(fieldOutline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change mission, currently \(missionType.title)")
    }

    private var soundField: some View {
        Button {
            showSoundPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sound")
                    .font(AlarmEditorStyle.sectionCaption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .center, spacing: 12) {
                    Label(alarmSound.title, systemImage: alarmSound.systemImageName)
                        .font(AlarmEditorStyle.body)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(AlarmEditorStyle.fieldPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground)
            .overlay(fieldOutline)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change sound, currently \(alarmSound.title)")
    }

    private var alarmOnRow: some View {
        Toggle("Alarm on", isOn: $isEnabled)
            .font(AlarmEditorStyle.body)
            .padding(AlarmEditorStyle.fieldPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground)
            .overlay(fieldOutline)
            .tint(AppTheme.toggleTint)
    }

    private var deleteAlarmButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete alarm", systemImage: "trash")
                .font(AlarmEditorStyle.bodyEmphasis)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AlarmEditorStyle.fieldPadding)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fieldBackground)
        .overlay(fieldOutline)
    }

    private var editorScrollBackground: Color {
        AppTheme.groupedScreenBackground
    }

    private var fieldFillColor: Color {
        AppTheme.cardFill
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: AlarmEditorStyle.fieldCorner, style: .continuous)
            .fill(fieldFillColor)
    }

    private var fieldOutline: some View {
        RoundedRectangle(cornerRadius: AlarmEditorStyle.fieldCorner, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }

    private var saveButtonTint: Color {
        colorScheme == .dark ? .white : .black
    }

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                saveAndDismiss()
            } label: {
                Text("Save")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(saveButtonTint)
            .padding(.horizontal, AlarmEditorStyle.fieldPadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private func saveAndDismiss() {
        var finalRepeatDays: [Weekday]
        if scheduleMode == .oneTime {
            finalRepeatDays = []
        } else {
            finalRepeatDays = Array(repeatDays).sorted()
            if finalRepeatDays.isEmpty {
                finalRepeatDays = [.monday]
            }
        }

        var alarm: Alarm
        if let id = editingAlarmID, let existing = alarmStore.alarm(id: id) {
            alarm = existing
        } else {
            alarm = Alarm(
                title: "",
                hour: pickerHour,
                minute: pickerMinute,
                repeatDays: finalRepeatDays,
                scheduleMode: scheduleMode,
                isEnabled: isEnabled,
                missionType: missionType,
                alarmSound: alarmSound
            )
        }

        alarm.title = alarmTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        alarm.hour = pickerHour
        alarm.minute = pickerMinute
        alarm.missionType = missionType
        alarm.alarmSound = alarmSound
        alarm.isEnabled = isEnabled
        alarm.scheduleMode = scheduleMode
        alarm.repeatDays = finalRepeatDays

        alarmStore.upsert(alarm)
        dismiss()
    }

    private func deleteAndDismiss() {
        guard let id = editingAlarmID else { return }
        alarmStore.delete(id)
        dismiss()
    }
}

/// Repeat-day picker styled like the Insights week strip.
private struct WeekdayRowPicker: View {
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Weekday.sundayThroughSaturday, id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Repeat days")
    }

    private func dayCell(_ day: Weekday) -> some View {
        let selected = selectedDays.contains(day)
        let isToday = day == todayWeekday

        return Button {
            toggle(day)
        } label: {
            VStack(spacing: 5) {
                Text(day.shortName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? AppTheme.sunAccent : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                ZStack {
                    Circle()
                        .fill(selected ? AppTheme.sunAccent.opacity(0.22) : Color.primary.opacity(0.07))
                        .frame(width: 30, height: 30)

                    if isToday {
                        Circle()
                            .strokeBorder(AppTheme.sunAccent.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                    }

                    Image(systemName: selected ? "checkmark" : "minus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selected ? AppTheme.sunAccent : Color.secondary.opacity(0.4))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.shortName)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var todayWeekday: Weekday? {
        let component = Calendar.current.component(.weekday, from: Date())
        return Weekday.fromCalendarWeekday(component)
    }

    private func toggle(_ day: Weekday) {
        if selectedDays.contains(day) {
            guard selectedDays.count > 1 else { return }
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}

private struct PickerSheetCloseButton: View {
    var onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

private struct MissionPickerSheet: View {
    @Binding var selection: MissionType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MissionType.allCases) { type in
                        Button {
                            selection = type
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Image(systemName: type.systemImageName)
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .center)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.title)
                                        .font(AlarmEditorStyle.bodyEmphasis)
                                        .foregroundStyle(.primary)
                                    Text(type.pickerDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 8)

                                if selection == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } footer: {
                    Text("Choose how you’ll dismiss this alarm when it fires.")
                        .font(.caption)
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
#endif
            .navigationTitle("Choose mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    PickerSheetCloseButton { dismiss() }
                }
            }
            .tint(.primary)
        }
    }
}

private struct SoundPickerSheet: View {
    @Binding var selection: AlarmSound
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AlarmSound.allCases) { sound in
                        soundRow(sound)
                    }
                } footer: {
                    Text("Tap a sound to select it. Use the speaker icon to preview.")
                        .font(.caption)
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
#endif
            .navigationTitle("Choose sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    PickerSheetCloseButton {
                        AlarmSoundPreviewPlayer.shared.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                AlarmSoundPreviewPlayer.shared.stop()
            }
            .tint(.primary)
        }
    }

    private func soundRow(_ sound: AlarmSound) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                selection = sound
                AlarmSoundPreviewPlayer.shared.stop()
                dismiss()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Image(systemName: sound.systemImageName)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sound.title)
                            .font(AlarmEditorStyle.bodyEmphasis)
                            .foregroundStyle(.primary)
                        Text(sound.pickerDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    if selection == sound {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                AlarmSoundPreviewPlayer.shared.play(sound)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(sound.title)")
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

private struct AlarmTimePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Time",
                    selection: $date,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AlarmEditorStyle.bodyEmphasis)
                }
            }
        }
    }
}

#Preview {
    AlarmEditorView(editingAlarmID: nil)
        .environmentObject(AlarmStore.mock())
}
