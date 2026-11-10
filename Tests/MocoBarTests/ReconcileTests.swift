import XCTest
@testable import MocoBar

final class ReconcileTests: XCTestCase {
    func testCompareIncludesAbsenceWhenRequested() {
        let excel = [ExcelDay(date: "2026-11-02", worked: 7.5, absence: 0.5)]

        let included = ExcelImport.compare(
            excel: excel,
            moco: ["2026-11-02": 8],
            includeAbsence: true
        )
        let excluded = ExcelImport.compare(
            excel: excel,
            moco: ["2026-11-02": 8],
            includeAbsence: false
        )

        XCTAssertEqual(included.first?.excel, 8)
        XCTAssertEqual(included.first?.status, .ok)
        XCTAssertEqual(excluded.first?.excel, 7.5)
        XCTAssertEqual(excluded.first?.absence, 0.5)
        XCTAssertEqual(excluded.first?.status, .tooMuch)
    }

    func testCompareClassifiesDailyDifferencesAndSortsRows() {
        let excel = [
            ExcelDay(date: "2026-11-03", worked: 8),
            ExcelDay(date: "2026-11-01", worked: 8),
            ExcelDay(date: "2026-11-02", worked: 8)
        ]
        let moco = [
            "2026-11-01": 7.5,
            "2026-11-02": 8.5,
            "2026-11-04": 1
        ]

        let rows = ExcelImport.compare(excel: excel, moco: moco, includeAbsence: false)

        XCTAssertEqual(rows.map(\.date), [
            "2026-11-01",
            "2026-11-02",
            "2026-11-03",
            "2026-11-04"
        ])
        XCTAssertEqual(rows.map(\.status), [.tooLittle, .tooMuch, .missingInMoco, .onlyInMoco])
    }

    func testCompareTreatsValuesWithinToleranceAsMatching() {
        let rows = ExcelImport.compare(
            excel: [ExcelDay(date: "2026-11-02", worked: 8)],
            moco: ["2026-11-02": 8.02],
            includeAbsence: false
        )

        XCTAssertEqual(rows.first?.status, .ok)
    }

    func testCompareOmitsMocoOnlyValuesAtOrBelowTolerance() {
        let rows = ExcelImport.compare(
            excel: [],
            moco: ["2026-11-02": 0.02],
            includeAbsence: false
        )

        XCTAssertTrue(rows.isEmpty)
    }
}
