import XCTest
@testable import timer

final class AlarmModelsTests: XCTestCase {
    func testWeekdayOrder() {
        XCTAssertLessThan(Weekday.monday, Weekday.tuesday)
        XCTAssertEqual(Weekday.sunday.shortName, "Sun")
    }

    func testAlarmCodableRoundTrip() throws {
        let alarm = Alarm(
            title: "Test",
            hour: 6,
            minute: 15,
            repeatDays: [.monday, .friday],
            scheduleMode: .scheduled,
            isEnabled: true,
            missionType: .voice,
            alarmSound: .pulse
        )
        let data = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)
        XCTAssertEqual(decoded, alarm)
    }

    func testMissionTypeAllCasesIncludesCoreMissions() {
        XCTAssertTrue(MissionType.allCases.contains(.voice))
        XCTAssertTrue(MissionType.allCases.contains(.math))
        XCTAssertTrue(MissionType.allCases.contains(.steps))
        XCTAssertTrue(MissionType.allCases.contains(.pushups))
        XCTAssertTrue(MissionType.allCases.contains(.objectHunt))
    }

    func testAlarmSoundProvidesTitlesForAllCases() {
        for sound in AlarmSound.allCases {
            XCTAssertFalse(sound.title.isEmpty)
            XCTAssertFalse(sound.pickerDescription.isEmpty)
        }
        XCTAssertEqual(AlarmSound.allCases.count, 6)
    }
}
