import XCTest
@testable import timer
#if canImport(UIKit)
import UIKit
#endif

final class MissionVerificationTests: XCTestCase {
    func testTextMatchesExactPhrase() {
        XCTAssertTrue(MissionVerifiers.textMatches(input: "I am awake", expectedPhrase: "I am awake"))
        XCTAssertTrue(MissionVerifiers.textMatches(input: "  i am awake  ", expectedPhrase: "I am awake"))
        XCTAssertFalse(MissionVerifiers.textMatches(input: "I am asleep", expectedPhrase: "I am awake"))
    }

    func testTextMatchesCollapsesInternalWhitespace() {
        XCTAssertTrue(MissionVerifiers.textMatches(input: "i   am\tawake", expectedPhrase: "I am awake"))
    }

    func testVoiceTranscriptContainsPhrase() {
        XCTAssertTrue(MissionVerifiers.voiceTranscriptMatches("okay i am awake now", expectedPhrase: "i am awake"))
        XCTAssertFalse(MissionVerifiers.voiceTranscriptMatches("still tired", expectedPhrase: "i am awake"))
    }

    func testMathAnswerValidation() {
        let challenge = MissionVerifiers.MathChallenge(prompt: "3 + 4 = ?", answer: 7)
        XCTAssertTrue(MissionVerifiers.mathAnswerMatches(input: "7", expected: challenge.answer))
        XCTAssertFalse(MissionVerifiers.mathAnswerMatches(input: "8", expected: challenge.answer))
        XCTAssertFalse(MissionVerifiers.mathAnswerMatches(input: "seven", expected: challenge.answer))
    }

    func testMathChallengeGeneration() {
        let normal = MissionVerifiers.generateMathChallenge(level: .normal)
        XCTAssertTrue(normal.prompt.contains("+"))

        let strict = MissionVerifiers.generateMathChallenge(level: .strict)
        XCTAssertTrue(strict.prompt.contains("×"))
    }

    func testMissionRequirementsScaleWithStrict() {
        let normal = MissionRequirements(verificationLevel: .normal)
        let strict = MissionRequirements(verificationLevel: .strict)

        XCTAssertLessThan(normal.requiredShakeCount, strict.requiredShakeCount)
        XCTAssertLessThan(normal.requiredStepCount, strict.requiredStepCount)
        XCTAssertLessThan(normal.requiredPushupCount, strict.requiredPushupCount)
        XCTAssertLessThan(normal.photoMinimumSkyBrightness, strict.photoMinimumSkyBrightness)
        XCTAssertTrue(strict.photoRequiresCameraOnly)
        XCTAssertFalse(normal.photoRequiresCameraOnly)
    }

    func testMissionTypeIncludesNewCases() {
        XCTAssertTrue(MissionType.allCases.contains(.pushups))
        XCTAssertFalse(MissionType.allCases.contains(where: { $0.rawValue == "hanumanChalisa" }))
        XCTAssertTrue(MissionType.allCases.contains(.math))
        XCTAssertTrue(MissionType.allCases.contains(.steps))
        XCTAssertEqual(MissionType.fromStored("pushups"), .pushups)
        XCTAssertEqual(MissionType.fromStored("hanumanChalisa"), .readBible)
    }

    func testMissionTypeCapabilityFlags() {
        XCTAssertTrue(MissionType.voice.requiresMicrophone)
        XCTAssertFalse(MissionType.text.requiresMicrophone)

        XCTAssertTrue(MissionType.photo.requiresCamera)
        XCTAssertTrue(MissionType.pushups.requiresCamera)
        XCTAssertFalse(MissionType.math.requiresCamera)

        XCTAssertTrue(MissionType.shake.requiresMotion)
        XCTAssertTrue(MissionType.steps.requiresMotion)
        XCTAssertFalse(MissionType.photo.requiresMotion)
    }

#if canImport(UIKit)
    func testPhotoSkyCheckPassesForBrightTopRegion() {
        let image = Self.makeSolidImage(color: .white, size: CGSize(width: 80, height: 80))
        XCTAssertTrue(MissionVerifiers.photoPassesSkyCheck(image, minimumTopBrightness: 70))
    }

    func testPhotoSkyCheckFailsForDarkImage() {
        let image = Self.makeSolidImage(color: .black, size: CGSize(width: 80, height: 80))
        XCTAssertFalse(MissionVerifiers.photoPassesSkyCheck(image, minimumTopBrightness: 70))
    }

    private static func makeSolidImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
#endif
}
