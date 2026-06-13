import XCTest
@testable import timer

final class ObjectHuntVerifierTests: XCTestCase {
    func testRandomTargetReturnsCatalogEntry() {
        let target = HuntObjectCatalog.randomTarget()
        XCTAssertTrue(HuntObjectCatalog.all.contains(target))
        XCTAssertFalse(target.displayName.isEmpty)
        XCTAssertFalse(target.visionLabels.isEmpty)
    }

    func testRandomTargetCanExcludeCurrentObject() {
        let current = HuntObjectCatalog.object(withId: "coffee_mug")!
        for _ in 0 ..< 20 {
            let next = HuntObjectCatalog.randomTarget(excluding: current)
            XCTAssertNotEqual(next.id, current.id)
        }
    }

    func testObjectLookupById() {
        XCTAssertEqual(HuntObjectCatalog.object(withId: "coffee_mug")?.displayName, "Coffee mug")
        XCTAssertNil(HuntObjectCatalog.object(withId: "keys"))
    }

    func testHuntObjectMatchesPrimaryLabel() {
        let target = HuntObjectCatalog.object(withId: "toothbrush")!
        let observations = [(identifier: "toothbrush", confidence: Float(0.45))]
        XCTAssertTrue(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.40
            )
        )
    }

    func testHuntObjectRejectsLowConfidence() {
        let target = HuntObjectCatalog.object(withId: "banana")!
        let observations = [(identifier: "banana", confidence: Float(0.05))]
        XCTAssertFalse(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.18
            )
        )
    }

    func testHuntObjectRejectsWrongLabel() {
        let target = HuntObjectCatalog.object(withId: "laptop")!
        let observations = [(identifier: "toothbrush", confidence: Float(0.90))]
        XCTAssertFalse(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.40
            )
        )
    }

    func testGenericLabelUsesHigherThreshold() {
        let target = HuntObjectCatalog.object(withId: "coffee_mug")!
        let borderline = [(identifier: "cup", confidence: Float(0.20))]
        XCTAssertFalse(
            MissionVerifiers.huntObjectMatches(
                observations: borderline,
                target: target,
                minConfidence: 0.18
            )
        )

        let confident = [(identifier: "cup", confidence: Float(0.35))]
        XCTAssertTrue(
            MissionVerifiers.huntObjectMatches(
                observations: confident,
                target: target,
                minConfidence: 0.18
            )
        )
    }

    func testHuntObjectMatchesSuffixIdentifiers() {
        let target = HuntObjectCatalog.object(withId: "coffee_mug")!
        let observations = [(identifier: "some_tag_coffee_mug", confidence: Float(0.25))]
        XCTAssertTrue(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.18
            )
        )
    }

    func testHuntObjectMatchesPrefixIdentifiers() {
        let target = HuntObjectCatalog.object(withId: "orange")!
        let observations = [(identifier: "orange_fruit", confidence: Float(0.20))]
        XCTAssertTrue(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.18
            )
        )
    }

    func testOrangeMatchesCitrusFruitLabel() {
        let target = HuntObjectCatalog.object(withId: "orange")!
        let observations = [(identifier: "citrus_fruit", confidence: Float(0.16))]
        XCTAssertTrue(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.18
            )
        )
    }

    func testOrangeMatchesLowConfidencePrimaryLabel() {
        let target = HuntObjectCatalog.object(withId: "orange")!
        let observations = [(identifier: "orange", confidence: Float(0.13))]
        XCTAssertTrue(
            MissionVerifiers.huntObjectMatches(
                observations: observations,
                target: target,
                minConfidence: 0.18
            )
        )
    }

    func testMissionTypeIncludesObjectHunt() {
        XCTAssertTrue(MissionType.allCases.contains(.objectHunt))
        XCTAssertEqual(MissionType.fromStored("objectHunt"), .objectHunt)
        XCTAssertTrue(MissionType.objectHunt.requiresCamera)
    }

    func testObjectHuntConfidenceThresholds() {
        let normal = MissionRequirements(verificationLevel: .normal)
        let strict = MissionRequirements(verificationLevel: .strict)
        XCTAssertLessThan(normal.objectHuntMinConfidence, strict.objectHuntMinConfidence)
        XCTAssertEqual(normal.objectHuntMinConfidence, 0.18, accuracy: 0.001)
        XCTAssertEqual(strict.objectHuntMinConfidence, 0.35, accuracy: 0.001)
    }
}
