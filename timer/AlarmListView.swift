#if os(iOS)
import UIKit
#endif
import SwiftUI

private enum AlarmListStyle {
    static let horizontalPadding: CGFloat = AppTheme.screenHorizontalPadding
}

/// Drives `.sheet(item:)` so the editor always receives the alarm that was tapped (not `nil` / 7:00 default).
private enum AlarmEditorSheetItem: Identifiable {
    case newAlarm
    case edit(Alarm)

    var id: String {
        switch self {
        case .newAlarm: "new-alarm"
        case .edit(let alarm): alarm.id.uuidString
        }
    }

    var editingAlarmID: UUID? {
        switch self {
        case .newAlarm: nil
        case .edit(let alarm): alarm.id
        }
    }
}

struct AlarmListView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var editorSheetItem: AlarmEditorSheetItem?
    @State private var alarmPendingDelete: Alarm?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    TimerScreenTitle(title: "Alarms")

                    if alarmStore.alarms.isEmpty {
                        ScrollView {
                            emptyState
                                .frame(maxWidth: .infinity, minHeight: 380)
                        }
                        .scrollContentBackground(.hidden)
                    } else {
                        alarmsList
                    }
                }
                .timerTabScreenInsets()
                .timerScreenBackground()

                addAlarmFloatingButton
                    .padding(.trailing, AlarmListStyle.horizontalPadding)
                    .padding(.bottom, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editorSheetItem) { item in
                AlarmEditorView(editingAlarmID: item.editingAlarmID)
                    .environmentObject(alarmStore)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Delete alarm?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let alarm = alarmPendingDelete {
                        alarmStore.delete(alarm.id)
                    }
                    alarmPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    alarmPendingDelete = nil
                }
            } message: {
                if let alarm = alarmPendingDelete {
                    Text("“\(alarm.listDisplayName)” at \(Alarm.formattedTime(hour: alarm.hour, minute: alarm.minute)) will be removed.")
                }
            }
        }
    }

    private var alarmsList: some View {
        VStack(spacing: AppTheme.screenBlockSpacing) {
            AlarmPermissionBanner()
                .environmentObject(alarmStore)

            List {
                ForEach(alarmStore.alarms) { alarm in
                    alarmCard(alarm)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: AppTheme.screenBlockSpacing,
                            trailing: 0
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                confirmDelete(alarm)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
        .padding(.bottom, 88)
    }

    private func confirmDelete(_ alarm: Alarm) {
        alarmPendingDelete = alarm
        showDeleteConfirmation = true
    }

    private var fabFillColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var fabIconColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var addAlarmFloatingButton: some View {
        Button {
            editorSheetItem = .newAlarm
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(fabIconColor)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(fabFillColor)
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add alarm")
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "alarm.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("No alarms yet")
                    .font(.title3.weight(.semibold))
                Text("Add an alarm to wake up with a mission—shake, photo, object hunt, voice, or typed phrase.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                editorSheetItem = .newAlarm
            } label: {
                Label("Create alarm", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(fabFillColor)
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func alarmCard(_ alarm: Alarm) -> some View {
        alarmRow(alarm)
            .padding(.horizontal, AlarmRowStyle.horizontalPadding)
            .padding(.vertical, AlarmRowStyle.verticalPadding)
            .timerListRowBackground()
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    confirmDelete(alarm)
                }
            }
    }

    private func alarmRow(_ alarm: Alarm) -> some View {
        let enabled = alarm.isEnabled
        let timeText = Alarm.formattedTime(hour: alarm.hour, minute: alarm.minute)

        return HStack(alignment: .center, spacing: AlarmRowStyle.rowSpacing) {
            Button {
                editorSheetItem = .edit(alarm)
            } label: {
                VStack(alignment: .leading, spacing: AlarmRowStyle.contentSpacing) {
                    Text(alarm.listDisplayName)
                        .font(AlarmRowStyle.nameFont)
                        .foregroundStyle(Color.secondary.opacity(enabled ? 1 : 0.55))
                        .lineLimit(1)

                    Text(timeText)
                        .font(AlarmRowStyle.timeFont)
                        .monospacedDigit()
                        .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.45))

                    AlarmRowMetaLine(alarm: alarm, enabled: enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityEditLabel(for: alarm))

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { newValue in
                    alarmStore.setEnabled(alarm.id, isEnabled: newValue)
                }
            ))
            .labelsHidden()
            .tint(AppTheme.toggleTint)
        }
    }

    private func accessibilityEditLabel(for alarm: Alarm) -> String {
        let time = Alarm.formattedTime(hour: alarm.hour, minute: alarm.minute)
        let schedule = alarm.listScheduleLabel
        let mission = alarm.missionType.title
        return "Edit alarm \(alarm.listDisplayName), \(time), \(schedule), mission \(mission)"
    }
}

#Preview {
    AlarmListView()
        .environmentObject(AlarmStore.mock())
}
