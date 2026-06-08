import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var wakeHistory: WakeHistoryStore
    @EnvironmentObject private var alarmStore: AlarmStore

#if os(iOS)
    var onOpenAlarms: (() -> Void)?
#endif

    /// Header title — short weekday + month/day so it fits next to the streak badge.
    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return f
    }()

    /// Accessibility-friendly long form for VoiceOver.
    private static let headerAccessibilityFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return f
    }()

    private static let upcomingDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    todayHeaderRow
                    weekDayStrip
                    nextWakeUpSection
                }
                .timerTabScreenInsets()
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .timerScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var todayHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(Self.headerDateFormatter.string(from: Date()))
                .font(AppTheme.screenTitleFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            streakBadge
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Today, \(Self.headerAccessibilityFormatter.string(from: Date()))")
    }

    private var streakBadge: some View {
        let streak = wakeHistory.currentStreakDays

        return HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text("\(streak)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
        )
        .accessibilityLabel("\(streak) day streak")
    }

    private var weekDayStrip: some View {
        WeekActivityStripView(days: WeekActivityStripView.sundayThroughSaturday)
    }

    // MARK: - Next wake up

    private var nextWakeUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next wake up")
                .font(AppTheme.sectionHeaderFont)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if upcomingAlarms.isEmpty {
                emptyAlarmsCard
            } else {
                VStack(spacing: AppTheme.screenBlockSpacing) {
                    ForEach(upcomingAlarms) { alarm in
                        wakeUpAlarmRow(alarm)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var upcomingAlarms: [Alarm] {
        alarmStore.alarms
            .filter(\.isEnabled)
            .sorted { a, b in
                let da = a.nextFireDate() ?? .distantFuture
                let db = b.nextFireDate() ?? .distantFuture
                return da < db
            }
    }

    private func wakeUpAlarmRow(_ alarm: Alarm) -> some View {
        let fireDate = alarm.nextFireDate()
        let isNext = alarm.id == upcomingAlarms.first?.id

        return Button {
            openAlarms()
        } label: {
            HStack(alignment: .center, spacing: AlarmRowStyle.rowSpacing) {
                VStack(alignment: .leading, spacing: AlarmRowStyle.contentSpacing) {
                    if let fireDate, let dayLabel = upcomingDayLabel(for: fireDate) {
                        Text(dayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }

                    Text(alarm.listDisplayName)
                        .font(AlarmRowStyle.nameFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(Alarm.formattedTime(hour: alarm.hour, minute: alarm.minute))
                        .font(AlarmRowStyle.timeFont)
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    AlarmRowMetaLine(alarm: alarm)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AlarmRowStyle.horizontalPadding)
            .padding(.vertical, AlarmRowStyle.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wakeUpCardBackground(isPrimary: isNext)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyAlarmsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No alarms set")
                .font(.headline)

            Text("Add a wake-up alarm to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            alarmsActionButton(title: "Add alarm", systemImage: "plus.circle.fill")
        }
        .padding(.horizontal, AlarmRowStyle.horizontalPadding)
        .padding(.vertical, AlarmRowStyle.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .timerCardBackground()
    }

    // MARK: - Helpers

#if os(iOS)
    private func alarmsActionButton(title: String, systemImage: String) -> some View {
        Button {
            openAlarms()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
    }

    private func openAlarms() {
        onOpenAlarms?()
    }
#else
    private func alarmsActionButton(title: String, systemImage: String) -> some View {
        NavigationLink {
            AlarmListView()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
    }
#endif

    /// Label when the next ring is not today (avoids “Today” at top + “Tomorrow” on a card feeling contradictory).
    private func upcomingDayLabel(for fireDate: Date) -> String? {
        let calendar = Calendar.current
        if calendar.isDateInToday(fireDate) { return nil }
        if calendar.isDateInTomorrow(fireDate) { return "Tomorrow" }
        return Self.upcomingDayFormatter.string(from: fireDate)
    }

}

#Preview {
    Group {
#if os(iOS)
        HomeView(onOpenAlarms: {})
#else
        HomeView()
#endif
    }
    .environmentObject(WakeHistoryStore.mock())
    .environmentObject(AlarmStore.mock())
}
