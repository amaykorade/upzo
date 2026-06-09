import Foundation

/// Per-mission thresholds driven by alarm settings (normal vs strict).
struct MissionRequirements {
    let verificationLevel: MissionVerificationLevel

    var requiredShakeCount: Int {
        verificationLevel == .strict ? 18 : 12
    }

    var requiredStepCount: Int {
        verificationLevel == .strict ? 40 : 25
    }

    var requiredPushupCount: Int {
        verificationLevel == .strict ? 15 : 10
    }

    /// Seconds user must stay on the reading mission screen.
    var requiredReadingSeconds: Int {
        verificationLevel == .strict ? 25 : 15
    }

    var photoRequiresCameraOnly: Bool {
        verificationLevel == .strict
    }

    /// Top-row average brightness (0–255) to accept a sky/outdoor photo.
    var photoMinimumSkyBrightness: Int {
        verificationLevel == .strict ? 95 : 70
    }

    /// Minimum Vision classification confidence for object hunt missions.
    var objectHuntMinConfidence: Float {
        verificationLevel == .strict ? 0.35 : 0.18
    }

    var textPhrase: String {
        verificationLevel == .strict ? "I am fully awake now" : "I am awake"
    }

    var voicePhrase: String {
        verificationLevel == .strict ? "i am fully awake now" : "i am awake"
    }

    var voiceDisplayPhrase: String {
        verificationLevel == .strict ? "I am fully awake now" : "I am awake"
    }

    static func from(settings: AlarmAppSettingsStore) -> MissionRequirements {
        MissionRequirements(verificationLevel: settings.missionVerificationLevel)
    }
}

extension MissionType {
    var requiresMicrophone: Bool {
        self == .voice || self == .affirmations
    }

    var requiresCamera: Bool {
        self == .photo || self == .pushups || self == .objectHunt
    }

    var requiresMotion: Bool {
        self == .shake || self == .steps
    }
}
