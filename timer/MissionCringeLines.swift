import Foundation

/// Roast-style celebration copy for the mission success banner and social share card.
enum MissionCringeLines {
    private static let linesByMission: [MissionType: [String]] = [
        .shake: [
            "Phone shaken. Dignity still asleep.",
            "That shake had more energy than your entire week.",
            "You shook the phone harder than you shake your responsibilities.",
            "Arms awake. Brain loading…",
            "Congratulations on your first workout of the day.",
        ],
        .photo: [
            "Photo taken. Self-esteem still loading.",
            "You look awake. We both know that's a lie.",
            "Front camera survived this encounter.",
            "Proof of life submitted. Personality pending.",
            "That face says 'hire me' and 'help me' at the same time.",
        ],
        .text: [
            "Typed the phrase. Still can't type your excuses away.",
            "Fingers work. Motivation doesn't.",
            "You can spell 'discipline'. Try living it.",
            "Keyboard warrior reporting for duty.",
            "Words typed. Character arc missing.",
        ],
        .voice: [
            "You spoke. The neighbors are concerned.",
            "Voice mission complete. Confidence not detected.",
            "That was loud for someone who hates mornings.",
            "Your alarm heard you. Your goals didn't.",
            "Vocal warm-up done. Actual day not started.",
        ],
        .readBible: [
            "Read the verse. Still sinned before breakfast.",
            "Spiritually fed. Physically still in pajamas.",
            "The word was heard. The snooze button trembled.",
            "Morning devotion complete. Ego still needs work.",
            "Faith strengthened. Sleep schedule unchanged.",
        ],
        .affirmations: [
            "Affirmations read. Delusion levels rising.",
            "You said it out loud. Now do it.",
            "Positive vibes unlocked. Negative habits still equipped.",
            "Main character energy… for 30 seconds.",
            "You affirmed it. The universe is skeptical.",
        ],
        .math: [
            "Math solved. Adulting still unsolved.",
            "Brain cells woke up before you did.",
            "Correct answer. Wrong life choices.",
            "Numbers don't lie. Your sleep schedule does.",
            "You can do algebra at 6 AM. Impressive and sad.",
        ],
        .steps: [
            "Steps counted. Couch still winning.",
            "You walked. Revolutionary.",
            "Legs moved. Career still standing still.",
            "Step goal crushed. Life goals untouched.",
            "The floor has seen more of you than sunlight.",
        ],
        .pushups: [
            "Pushups done. Shirt still hasn't seen the gym.",
            "Arms burning. Accountability unlocked.",
            "One rep closer to not being a disappointment.",
            "Chest to floor. Standards still on the ground.",
            "You did pushups. Your excuses did not.",
        ],
        .objectHunt: [
            "Object found. Purpose still missing.",
            "Hunt complete. Dignity optional.",
            "You crawled for that. Respect the grind.",
            "Morning scavenger hunt champion. Life champion pending.",
            "Found it. Now find a reason to stay awake.",
        ],
    ]

    static func randomLine(for missionType: MissionType) -> String {
        linesByMission[missionType]?.randomElement()
            ?? "You woke up. That's more than yesterday."
    }

    static func randomLine(for missionType: MissionType, object: HuntObject?) -> String {
        if missionType == .objectHunt, let object, let line = HuntObjectCringeLines.randomLine(for: object) {
            return line
        }
        return randomLine(for: missionType)
    }
}
