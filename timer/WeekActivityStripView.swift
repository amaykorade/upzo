import SwiftUI

/// Shared week activity row (Insights + Home): weekday label above circle with check or minus.
struct WeekActivityStripView: View {
    @EnvironmentObject private var wakeHistory: WakeHistoryStore

    let days: [Date]

    private static let shortWeekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayCell(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Week activity")
    }

    private func dayCell(for day: Date) -> some View {
        let success = wakeHistory.hadWake(onDayContaining: day)
        let isToday = Calendar.current.isDateInToday(day)

        return VStack(spacing: 5) {
            Text(Self.shortWeekday.string(from: day))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? AppTheme.sunAccent : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            ZStack {
                Circle()
                    .fill(success ? AppTheme.sunAccent.opacity(0.22) : Color.primary.opacity(0.07))
                    .frame(width: 30, height: 30)

                if isToday {
                    Circle()
                        .strokeBorder(AppTheme.sunAccent.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }

                Image(systemName: success ? "checkmark" : "minus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(success ? AppTheme.sunAccent : Color.secondary.opacity(0.4))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(Self.shortWeekday.string(from: day)), \(success ? "completed" : "no wake")\(isToday ? ", today" : "")"
        )
    }
}

extension WeekActivityStripView {
    /// Current calendar week, Sunday through Saturday.
    static var sundayThroughSaturday: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        guard let sunday = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) else {
            return []
        }
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }

    /// Rolling last seven days ending today.
    static var lastSevenDays: [Date] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0 - 6, to: anchor) }
    }
}
