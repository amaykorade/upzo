import Foundation

struct WakeEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var alarmId: UUID
    var completedAt: Date
    var missionType: MissionType
    /// Seconds from opening the mission screen to finishing it.
    var responseSeconds: Int?
    /// Alarm tone used when this wake-up was logged.
    var alarmSound: AlarmSound?

    init(
        id: UUID = UUID(),
        alarmId: UUID,
        completedAt: Date = Date(),
        missionType: MissionType,
        responseSeconds: Int? = nil,
        alarmSound: AlarmSound? = nil
    ) {
        self.id = id
        self.alarmId = alarmId
        self.completedAt = completedAt
        self.missionType = missionType
        self.responseSeconds = responseSeconds
        self.alarmSound = alarmSound
    }

    enum CodingKeys: String, CodingKey {
        case id, alarmId, completedAt, missionType, responseSeconds, alarmSound
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        alarmId = try c.decode(UUID.self, forKey: .alarmId)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        missionType = MissionType.fromStored(try c.decode(String.self, forKey: .missionType))
        responseSeconds = try c.decodeIfPresent(Int.self, forKey: .responseSeconds)
        alarmSound = try c.decodeIfPresent(AlarmSound.self, forKey: .alarmSound)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(alarmId, forKey: .alarmId)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(missionType, forKey: .missionType)
        try c.encodeIfPresent(responseSeconds, forKey: .responseSeconds)
        try c.encodeIfPresent(alarmSound, forKey: .alarmSound)
    }
}

struct WakeBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImageName: String
}

enum WakeBadgeCatalog {
    static func earned(streakDays: Int, totalWakes: Int, events: [WakeEvent]) -> [WakeBadge] {
        var badges: [WakeBadge] = []

        if totalWakes >= 1 {
            badges.append(WakeBadge(id: "first_wake", title: "First wake", systemImageName: "sunrise.fill"))
        }
        if streakDays >= 3 {
            badges.append(WakeBadge(id: "streak_3", title: "3-day streak", systemImageName: "flame.fill"))
        }
        if streakDays >= 7 {
            badges.append(WakeBadge(id: "streak_7", title: "7-day streak", systemImageName: "flame.circle.fill"))
        }
        if streakDays >= 30 {
            badges.append(WakeBadge(id: "streak_30", title: "30-day streak", systemImageName: "crown.fill"))
        }
        if totalWakes >= 10 {
            badges.append(WakeBadge(id: "ten_wakes", title: "10 wakes", systemImageName: "10.circle.fill"))
        }

        let missionKinds = Set(events.map(\.missionType))
        if missionKinds.count >= MissionType.allCases.count {
            badges.append(WakeBadge(id: "all_missions", title: "Mission pro", systemImageName: "star.fill"))
        }

        return badges
    }
}
