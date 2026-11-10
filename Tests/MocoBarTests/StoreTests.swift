import XCTest
@testable import MocoBar

final class StoreTests: XCTestCase {
    func testParseDurationAcceptsSupportedFormats() {
        let cases: [(input: String, expectedSeconds: Int)] = [
            ("2h", 7_200),
            ("1,5h", 5_400),
            ("1:30", 5_400),
            ("45m", 2_700),
            ("45", 2_700),
            (" 2 H ", 7_200),
            ("0", 0)
        ]

        for testCase in cases {
            XCTAssertEqual(
                Store.parseDuration(testCase.input),
                testCase.expectedSeconds,
                "Unexpected result for \(testCase.input)"
            )
        }
    }

    func testParseDurationRejectsUnsupportedFormats() {
        for input in ["", "abc", "h", "m", ":", "1:30:00"] {
            XCTAssertNil(Store.parseDuration(input), "Expected \(input) to be rejected")
        }
    }

    func testFormatHoursRoundsToWholeMinutes() {
        XCTAssertEqual(Store.format(hours: 8), "8:00 h")
        XCTAssertEqual(Store.format(hours: 1.5), "1:30 h")
        XCTAssertEqual(Store.format(hours: 0.999), "1:00 h")
    }
}
