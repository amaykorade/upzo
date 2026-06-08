import Foundation

enum AlarmRowFormatting {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static func timeString(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return timeFormatter.string(from: date)
    }

    static func repeatSummary(days: [Weekday]) -> String {
        let sorted = Set(days).sorted()
        if sorted.isEmpty { return "No days" }
        if sorted.count == Weekday.allCases.count { return "Every day" }
        if sorted == [.monday, .tuesday, .wednesday, .thursday, .friday] {
            return "Weekdays"
        }
        if sorted == [.saturday, .sunday] { return "Weekends" }
        return sorted.map(\.shortName).joined(separator: " · ")
    }
}
