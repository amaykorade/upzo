import Foundation

// MARK: - Profile basics

enum OnboardingAgeRange: String, CaseIterable, Codable, Identifiable {
    case under18
    case age18to24
    case age25to34
    case age35to44
    case age45to54
    case age55Plus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .under18: "Under 18"
        case .age18to24: "18–24"
        case .age25to34: "25–34"
        case .age35to44: "35–44"
        case .age45to54: "45–54"
        case .age55Plus: "55+"
        }
    }

    var systemImage: String {
        switch self {
        case .under18: "figure.child.circle.fill"
        case .age18to24: "figure.walk.circle.fill"
        case .age25to34: "figure.run.circle.fill"
        case .age35to44: "figure.stand.fill"
        case .age45to54: "figure.wave.circle.fill"
        case .age55Plus: "heart.circle.fill"
        }
    }
}

// MARK: - Wake-up questions

enum OnboardingMorningStruggle: String, CaseIterable, Codable, Identifiable {
    case oversleep
    case snooze
    case groggy
    case inconsistent
    case alarmFails

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oversleep: "I oversleep and wake up late"
        case .snooze: "I hit snooze again and again"
        case .groggy: "I'm groggy and can't get moving"
        case .inconsistent: "My schedule is all over the place"
        case .alarmFails: "My alarm doesn't wake me up"
        }
    }

    var systemImage: String {
        switch self {
        case .oversleep: "clock.badge.exclamationmark.fill"
        case .snooze: "repeat.circle.fill"
        case .groggy: "cloud.moon.fill"
        case .inconsistent: "calendar.badge.clock"
        case .alarmFails: "bell.slash.fill"
        }
    }
}

enum OnboardingSnoozeFrequency: String, CaseIterable, Codable, Identifiable {
    case rarely
    case onceOrTwice
    case threePlus
    case untilLate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rarely: "Almost never"
        case .onceOrTwice: "Once or twice"
        case .threePlus: "Three or more times"
        case .untilLate: "Until I'm running late"
        }
    }

    var systemImage: String {
        switch self {
        case .rarely: "checkmark.circle.fill"
        case .onceOrTwice: "1.circle.fill"
        case .threePlus: "repeat.circle.fill"
        case .untilLate: "exclamationmark.triangle.fill"
        }
    }
}

enum OnboardingSleeperType: String, CaseIterable, Codable, Identifiable {
    case light
    case average
    case heavy
    case alarmProof

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light sleeper"
        case .average: "Average sleeper"
        case .heavy: "Heavy sleeper"
        case .alarmProof: "Alarms barely wake me"
        }
    }

    var systemImage: String {
        switch self {
        case .light: "sun.min.fill"
        case .average: "moon.zzz.fill"
        case .heavy: "bed.double.fill"
        case .alarmProof: "speaker.slash.fill"
        }
    }
}

enum OnboardingWakeGoal: String, CaseIterable, Codable, Identifiable {
    case onTime
    case fitness
    case routine
    case lessStress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onTime: "Get to work or school on time"
        case .fitness: "Work out or move my body"
        case .routine: "Build a steady morning routine"
        case .lessStress: "Feel less stressed and rushed"
        }
    }

    var systemImage: String {
        switch self {
        case .onTime: "briefcase.fill"
        case .fitness: "figure.run.circle.fill"
        case .routine: "calendar.circle.fill"
        case .lessStress: "leaf.fill"
        }
    }
}

enum OnboardingMissionChoice: String, CaseIterable, Codable, Identifiable {
    case shake
    case steps
    case pushups
    case math
    case text
    case voice
    case photo
    case objectHunt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shake: "Shake my phone"
        case .steps: "Walk a set number of steps"
        case .pushups: "Do pushups in front of the camera"
        case .math: "Solve a quick math problem"
        case .text: "Type a wake-up phrase"
        case .voice: "Say a phrase out loud"
        case .photo: "Take a sky or window photo"
        case .objectHunt: "Find and photograph a household object"
        }
    }

    var systemImage: String {
        switch self {
        case .shake: "iphone.radiowaves.left.and.right"
        case .steps: "figure.walk.circle.fill"
        case .pushups: "figure.strengthtraining.traditional"
        case .math: "plus.forwardslash.minus"
        case .text: "character.textbox"
        case .voice: "mic.fill"
        case .photo: "camera.fill"
        case .objectHunt: "magnifyingglass"
        }
    }

    var missionType: MissionType {
        switch self {
        case .shake: .shake
        case .steps: .steps
        case .pushups: .pushups
        case .math: .math
        case .text: .text
        case .voice: .voice
        case .photo: .photo
        case .objectHunt: .objectHunt
        }
    }
}

enum OnboardingStrictness: String, CaseIterable, Codable, Identifiable {
    case gentle
    case standard
    case strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: "Gentle — easier mission"
        case .standard: "Standard — balanced"
        case .strict: "Strict — don't let me cheat"
        }
    }

    var systemImage: String {
        switch self {
        case .gentle: "hand.wave.fill"
        case .standard: "slider.horizontal.3"
        case .strict: "lock.shield.fill"
        }
    }

    var verificationLevel: MissionVerificationLevel {
        switch self {
        case .gentle, .standard: .normal
        case .strict: .strict
        }
    }
}

enum OnboardingPhoneHabit: String, CaseIterable, Codable, Identifiable {
    case bedside
    case nearby
    case acrossRoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bedside: "Yes, right next to me"
        case .nearby: "Sometimes nearby"
        case .acrossRoom: "I leave it across the room"
        }
    }

    var systemImage: String {
        switch self {
        case .bedside: "iphone.gen3"
        case .nearby: "iphone.circle.fill"
        case .acrossRoom: "figure.walk.motion"
        }
    }
}

// MARK: - Story onboarding questions

enum OnboardingGender: String, CaseIterable, Codable, Identifiable {
    case female, male, nonBinary, preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .nonBinary: "Non-binary"
        case .preferNotToSay: "Prefer not to say"
        }
    }

    var systemImage: String {
        switch self {
        case .female: "figure.dress.line.vertical.figure"
        case .male: "figure.stand"
        case .nonBinary: "person.2.fill"
        case .preferNotToSay: "person.crop.circle.fill"
        }
    }
}

enum OnboardingMorningPerson: String, CaseIterable, Codable, Identifiable {
    case yes, sometimes, no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: "Yes, I'm a morning person"
        case .sometimes: "Sometimes"
        case .no: "Not at all"
        }
    }

    var systemImage: String {
        switch self {
        case .yes: "sun.max.fill"
        case .sometimes: "cloud.sun.fill"
        case .no: "moon.zzz.fill"
        }
    }
}

enum OnboardingReferralSource: String, CaseIterable, Codable, Identifiable {
    case appStore, friend, social, search, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appStore: "App Store"
        case .friend: "Friend or family"
        case .social: "Social media"
        case .search: "Web search"
        case .other: "Somewhere else"
        }
    }

    var systemImage: String {
        switch self {
        case .appStore: "arrow.down.circle.fill"
        case .friend: "person.2.fill"
        case .social: "heart.text.square.fill"
        case .search: "magnifyingglass.circle.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}

enum OnboardingAlarmCount: String, CaseIterable, Codable, Identifiable {
    case none, one, two, threePlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "I don't use alarms"
        case .one: "One alarm"
        case .two: "Two alarms"
        case .threePlus: "Three or more"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "bell.slash.fill"
        case .one: "bell.fill"
        case .two: "bell.badge.fill"
        case .threePlus: "bell.badge.waveform.fill"
        }
    }
}

enum OnboardingTrustFirstAlarm: String, CaseIterable, Codable, Identifiable {
    case yes, sometimes, no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: "Yes, I trust myself"
        case .sometimes: "Sometimes"
        case .no: "No — I need backup alarms"
        }
    }

    var systemImage: String {
        switch self {
        case .yes: "hand.thumbsup.fill"
        case .sometimes: "hand.raised.fill"
        case .no: "exclamationmark.triangle.fill"
        }
    }
}

enum OnboardingBackToSleep: String, CaseIterable, Codable, Identifiable {
    case never, sometimes, often

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Almost never"
        case .sometimes: "Sometimes"
        case .often: "Often — it's my biggest problem"
        }
    }

    var systemImage: String {
        switch self {
        case .never: "checkmark.circle.fill"
        case .sometimes: "arrow.uturn.backward.circle.fill"
        case .often: "bed.double.fill"
        }
    }
}

enum OnboardingNightFeeling: String, CaseIterable, Codable, Identifiable {
    case anxious, tired, hopeful, motivated, neutral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anxious: "Anxious about tomorrow"
        case .tired: "Exhausted"
        case .hopeful: "Hopeful I'll do better"
        case .motivated: "Motivated and good"
        case .neutral: "Neutral"
        }
    }

    var systemImage: String {
        switch self {
        case .anxious: "brain.head.profile.fill"
        case .tired: "battery.100percent.bolt"
        case .hopeful: "sparkles"
        case .motivated: "sun.max.fill"
        case .neutral: "minus.circle.fill"
        }
    }
}

enum OnboardingAlarmThought: String, CaseIterable, Codable, Identifiable {
    case snooze, fiveMore, panic, alreadyLate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snooze: "\"Just hit snooze\""
        case .fiveMore: "\"Five more minutes\""
        case .panic: "\"Oh no, I'm late\""
        case .alreadyLate: "\"I can skip today\""
        }
    }

    var systemImage: String {
        switch self {
        case .snooze: "repeat.circle.fill"
        case .fiveMore: "clock.badge.plus.fill"
        case .panic: "bolt.fill"
        case .alreadyLate: "figure.walk.departure"
        }
    }
}

enum OnboardingBedNegotiation: String, CaseIterable, Codable, Identifiable {
    case never, sometimes, almostAlways

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Rarely"
        case .sometimes: "Sometimes"
        case .almostAlways: "Almost every morning"
        }
    }

    var systemImage: String {
        switch self {
        case .never: "hand.thumbsup.fill"
        case .sometimes: "bubble.left.and.bubble.right.fill"
        case .almostAlways: "bed.double.fill"
        }
    }
}

enum OnboardingMorningFeeling: String, CaseIterable, Codable, Identifiable {
    case groggy, okay, energized, miserable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groggy: "Foggy and slow"
        case .okay: "Okay after a few minutes"
        case .energized: "Pretty energized"
        case .miserable: "Rough — I want to stay in bed"
        }
    }

    var systemImage: String {
        switch self {
        case .groggy: "cloud.fog.fill"
        case .okay: "face.smiling.fill"
        case .energized: "bolt.circle.fill"
        case .miserable: "cloud.rain.fill"
        }
    }
}

enum OnboardingAwakeDelay: String, CaseIterable, Codable, Identifiable {
    case under15, fifteenTo30, thirtyTo60, over60

    var id: String { rawValue }

    var title: String {
        switch self {
        case .under15: "Under 15 minutes"
        case .fifteenTo30: "15–30 minutes"
        case .thirtyTo60: "30–60 minutes"
        case .over60: "More than an hour"
        }
    }

    var systemImage: String {
        switch self {
        case .under15: "hare.fill"
        case .fifteenTo30: "clock.fill"
        case .thirtyTo60: "hourglass.circle.fill"
        case .over60: "tortoise.fill"
        }
    }
}

enum OnboardingBrainFogRemedy: String, CaseIterable, Codable, Identifiable {
    case coffee, shower, phone, movement, nothing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coffee: "Coffee or tea"
        case .shower: "A shower"
        case .phone: "Scrolling my phone"
        case .movement: "Moving my body"
        case .nothing: "Nothing really works"
        }
    }

    var systemImage: String {
        switch self {
        case .coffee: "cup.and.saucer.fill"
        case .shower: "shower.fill"
        case .phone: "iphone.gen3"
        case .movement: "figure.walk.motion"
        case .nothing: "xmark.circle.fill"
        }
    }
}

// MARK: - Persisted profile

struct OnboardingProfile: Codable, Equatable {
    var firstName: String?
    var gender: OnboardingGender?
    var morningPerson: OnboardingMorningPerson?
    var referralSource: OnboardingReferralSource?
    var alarmCount: OnboardingAlarmCount?
    var trustFirstAlarm: OnboardingTrustFirstAlarm?
    var backToSleep: OnboardingBackToSleep?
    var nightFeeling: OnboardingNightFeeling?
    var alarmThought: OnboardingAlarmThought?
    var bedNegotiation: OnboardingBedNegotiation?
    var morningFeeling: OnboardingMorningFeeling?
    var awakeDelay: OnboardingAwakeDelay?
    var brainFogRemedy: OnboardingBrainFogRemedy?
    var ageRange: OnboardingAgeRange?
    var morningStruggle: OnboardingMorningStruggle?
    var snoozeFrequency: OnboardingSnoozeFrequency?
    var sleeperType: OnboardingSleeperType?
    var wakeGoal: OnboardingWakeGoal?
    var wakeHour: Int
    var wakeMinute: Int
    var repeatDays: [Weekday]
    var missionChoice: OnboardingMissionChoice?
    var strictness: OnboardingStrictness?
    var phoneHabit: OnboardingPhoneHabit?
    var completedAt: Date?

    static let defaultWeekdayPreset: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    var recommendedMission: MissionType {
        missionChoice?.missionType ?? .shake
    }

    var trimmedFirstName: String? {
        guard let firstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines), !firstName.isEmpty else {
            return nil
        }
        return firstName
    }

    var planGreeting: String? {
        guard let name = trimmedFirstName else { return nil }
        return "Nice to meet you, \(name)"
    }

    var planHeadline: String {
        if let name = trimmedFirstName {
            return "\(name)'s wake-up plan"
        }
        if bedNegotiation == .almostAlways || backToSleep == .often {
            return "Built to beat the snooze trap"
        }
        if let struggle = morningStruggle {
            switch struggle {
            case .snooze, .oversleep:
                return "Built for serial snoozers"
            case .alarmFails:
                return "Built for heavy sleepers"
            case .groggy:
                return "Built to get you moving"
            case .inconsistent:
                return "Built for a steadier routine"
            }
        }
        return "Your personal wake-up plan"
    }

    var planDetail: String {
        let time = Alarm.formattedTime(hour: wakeHour, minute: wakeMinute)
        let mission = recommendedMission.title
        let days = AlarmRowFormatting.repeatSummary(days: repeatDays)
        return "Weekdays at \(time) · \(mission) mission · \(days). Finish the mission to stop the alarm."
    }

    var struggleCallback: String? {
        if bedNegotiation == .almostAlways {
            return "Wake-up missions engage your brain when willpower is still waking up — so negotiating with yourself gets harder."
        }
        guard let struggle = morningStruggle else { return nil }
        switch struggle {
        case .snooze: return "Since snoozing is your main struggle, we'll keep pressure on until your mission is done."
        case .oversleep: return "We'll ring with a system alarm and won't let you off until you're truly up."
        case .groggy: return "A quick mission will help your brain switch on faster than snooze alone."
        case .inconsistent: return "Repeating on your chosen days builds the routine you're missing."
        case .alarmFails: return "System alarms (like Clock) plus a mission give you a much stronger wake-up."
        }
    }
}
