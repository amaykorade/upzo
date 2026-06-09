import Foundation

enum Weekday: Int, CaseIterable, Codable, Hashable, Comparable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// `Calendar.Component.weekday`: 1 = Sunday … 7 = Saturday.
    static func fromCalendarWeekday(_ value: Int) -> Weekday? {
        switch value {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    /// Single letter above week circles: S M T W T F S.
    var singleLetterLabel: String {
        switch self {
        case .sunday: "S"
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        }
    }

    /// Short label for a single-row weekday strip (Sun → Sat).
    var compactStripLabel: String {
        switch self {
        case .sunday: "Su"
        case .monday: "Mo"
        case .tuesday: "Tu"
        case .wednesday: "W"
        case .thursday: "Th"
        case .friday: "Fr"
        case .saturday: "Sa"
        }
    }

    /// Sunday → Saturday for circular week UI (clockwise from Sunday at the top).
    static var sundayThroughSaturday: [Weekday] {
        [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    }
}

enum MissionType: String, CaseIterable, Codable, Identifiable, Hashable {
    case shake
    case photo
    case text
    case voice
    case readBible
    case affirmations
    case math
    case steps
    case pushups
    case objectHunt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shake: "Shake"
        case .photo: "Photo"
        case .text: "Text"
        case .voice: "Voice"
        case .readBible: "Read Bible"
        case .affirmations: "Affirmations"
        case .math: "Math"
        case .steps: "Steps"
        case .pushups: "Pushups"
        case .objectHunt: "Object hunt"
        }
    }

    var systemImageName: String {
        switch self {
        case .shake: "iphone.gen3"
        case .photo: "camera.fill"
        case .text: "text.bubble"
        case .voice: "mic.fill"
        case .readBible: "book.closed.fill"
        case .affirmations: "quote.bubble.fill"
        case .math: "function"
        case .steps: "figure.walk"
        case .pushups: "figure.strengthtraining.traditional"
        case .objectHunt: "magnifyingglass"
        }
    }

    /// One-line helper shown in the mission picker list.
    var pickerDescription: String {
        switch self {
        case .shake:
            return "Shake your iPhone repeatedly to prove you’re up."
        case .photo:
            return "Take a sky or window photo — verified before the alarm stops."
        case .text:
            return "Type an exact wake-up phrase (verified)."
        case .voice:
            return "Say the wake-up phrase; verified with speech recognition."
        case .readBible:
            return "Read a short Bible passage and scroll to the end."
        case .affirmations:
            return "Read wake-up affirmations out loud before dismiss."
        case .math:
            return "Solve a quick math problem to turn the alarm off."
        case .steps:
            return "Walk a set number of steps — motion is verified."
        case .pushups:
            return "Do pushups in front of the camera — reps are counted on device."
        case .objectHunt:
            return "Find and photograph a random household object — verified on device."
        }
    }

    /// Decodes a stored mission id; retired types map to a supported mission.
    static func fromStored(_ rawValue: String) -> MissionType {
        switch rawValue {
        case "objectHunt":
            return .objectHunt
        case "pushups":
            return .pushups
        case "hanumanChalisa":
            return .readBible
        default:
            return MissionType(rawValue: rawValue) ?? .shake
        }
    }
}

/// Repeating weekdays vs a single next occurrence (notifications; AlarmKit supports repeating only).
enum AlarmScheduleMode: String, Codable, Hashable, CaseIterable {
    case scheduled
    case oneTime
}

/// Wake tone for notifications and AlarmKit alerts. Bundled files live in the app target.
enum AlarmSound: String, CaseIterable, Codable, Identifiable, Hashable {
    case classic
    case pulse
    case chime
    case rise
    case beacon
    case phoneRingtone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .pulse: "Pulse"
        case .chime: "Chimes"
        case .rise: "Rise"
        case .beacon: "Beacon"
        case .phoneRingtone: "Phone ringtone"
        }
    }

    var systemImageName: String {
        switch self {
        case .classic: "bell.fill"
        case .pulse: "waveform.path"
        case .chime: "music.note"
        case .rise: "sunrise.fill"
        case .beacon: "dot.radiowaves.left.and.right"
        case .phoneRingtone: "iphone.radiowaves.left.and.right"
        }
    }

    var pickerDescription: String {
        switch self {
        case .classic:
            return "Long, steady wake tone — the app default."
        case .pulse:
            return "Rhythmic pulse built for mission wake-ups."
        case .chime:
            return "Light three-note chime."
        case .rise:
            return "Gradual ascending tone that gets louder."
        case .beacon:
            return "Repeating beacon pulses."
        case .phoneRingtone:
            return "Uses your iPhone’s default ringtone."
        }
    }
}

struct Alarm: Identifiable, Equatable {
    var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var repeatDays: [Weekday]
    var scheduleMode: AlarmScheduleMode
    var isEnabled: Bool
    var missionType: MissionType
    var alarmSound: AlarmSound

    init(
        id: UUID = UUID(),
        title: String = "",
        hour: Int,
        minute: Int,
        repeatDays: [Weekday] = [],
        scheduleMode: AlarmScheduleMode = .scheduled,
        isEnabled: Bool = true,
        missionType: MissionType = .shake,
        alarmSound: AlarmSound = .classic
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.scheduleMode = scheduleMode
        self.isEnabled = isEnabled
        self.missionType = missionType
        self.alarmSound = alarmSound
    }
}

extension Alarm: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, hour, minute, repeatDays, scheduleMode, isEnabled, missionType, alarmSound
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        repeatDays = try c.decodeIfPresent([Weekday].self, forKey: .repeatDays) ?? []
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        missionType = MissionType.fromStored(try c.decode(String.self, forKey: .missionType))
        scheduleMode = try c.decodeIfPresent(AlarmScheduleMode.self, forKey: .scheduleMode) ?? .scheduled
        alarmSound = try c.decodeIfPresent(AlarmSound.self, forKey: .alarmSound) ?? .classic
        if scheduleMode == .scheduled, repeatDays.isEmpty {
            repeatDays = [.monday]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(hour, forKey: .hour)
        try c.encode(minute, forKey: .minute)
        try c.encode(repeatDays, forKey: .repeatDays)
        try c.encode(scheduleMode, forKey: .scheduleMode)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(missionType, forKey: .missionType)
        try c.encode(alarmSound, forKey: .alarmSound)
    }
}

extension Alarm {
    private static let listTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// Local date for time pickers — anchored to today so hour/minute match what we store.
    static func pickerDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    /// Hour and minute in the user's calendar/time zone from a picker value.
    static func pickerTime(from date: Date) -> (hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }

    static func formattedTime(hour: Int, minute: Int) -> String {
        listTimeFormatter.string(from: pickerDate(hour: hour, minute: minute))
    }

    /// Next occurrence used for sorting and “next alarm” UI.
    func nextFireDate(from reference: Date = Date()) -> Date? {
        let cal = Calendar.current
        let ref = reference
        if scheduleMode == .oneTime {
            return cal.nextDate(
                after: ref.addingTimeInterval(-1),
                matching: DateComponents(hour: hour, minute: minute),
                matchingPolicy: .nextTime
            )
        }
        guard !repeatDays.isEmpty else { return nil }
        let allowed = Set(repeatDays)
        for offset in 0 ..< 14 {
            guard let dayStart = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: ref)) else { continue }
            let cw = cal.component(.weekday, from: dayStart)
            guard let wd = Weekday.fromCalendarWeekday(cw), allowed.contains(wd) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: dayStart)
            comps.hour = hour
            comps.minute = minute
            guard let candidate = cal.date(from: comps) else { continue }
            if candidate > ref { return candidate }
        }
        return nil
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? Self.formattedTime(hour: hour, minute: minute) : t
    }

    var displaySubtitle: String {
        let time = Self.formattedTime(hour: hour, minute: minute)
        let mission = missionType.title
        if scheduleMode == .oneTime {
            return "\(time) · \(mission) · One time"
        }
        let rep = AlarmRowFormatting.repeatSummary(days: repeatDays)
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            return "\(mission) · \(rep)"
        }
        return "\(time) · \(mission) · \(rep)"
    }

    /// Short schedule line for list rows: "Every day", "Weekdays", "One time", etc.
    var listScheduleLabel: String {
        if scheduleMode == .oneTime { return "One time" }
        return AlarmRowFormatting.repeatSummary(days: repeatDays)
    }

    /// Name shown on the alarms list; falls back when the user leaves the name field empty.
    var listDisplayName: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Alarm" : t
    }

#if os(iOS)
    /// True when `reference` is within `window` seconds after today's scheduled fire time for this alarm.
    func likelyFired(within window: TimeInterval, reference: Date = Date()) -> Bool {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let todayFire = calendar.date(from: components) else { return false }

        if scheduleMode == .oneTime {
            guard let fire = nextFireDate(from: reference.addingTimeInterval(-window - 60)) else { return false }
            let delta = reference.timeIntervalSince(fire)
            return delta >= 0 && delta <= window
        }

        guard !repeatDays.isEmpty else { return false }
        let weekday = calendar.component(.weekday, from: reference)
        guard let day = Weekday.fromCalendarWeekday(weekday), repeatDays.contains(day) else { return false }
        let delta = reference.timeIntervalSince(todayFire)
        return delta >= 0 && delta <= window
    }
#endif
}
