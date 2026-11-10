import XCTest
@testable import MocoBar

final class TimeReportTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testWeekIntervalStartsOnMonday() throws {
        let date = try makeDate("2026-11-04")
        let interval = try XCTUnwrap(ReportPeriod.week.interval(containing: date, calendar: calendar))
        let lastDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: interval.end))

        XCTAssertEqual(TimeReport.isoDate(interval.start, calendar: calendar), "2026-11-02")
        XCTAssertEqual(TimeReport.isoDate(lastDay, calendar: calendar), "2026-11-08")
    }

    func testMonthIntervalCoversWholeCalendarMonth() throws {
        let date = try makeDate("2026-11-10")
        let interval = try XCTUnwrap(ReportPeriod.month.interval(containing: date, calendar: calendar))
        let lastDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: interval.end))

        XCTAssertEqual(TimeReport.isoDate(interval.start, calendar: calendar), "2026-11-01")
        XCTAssertEqual(TimeReport.isoDate(lastDay, calendar: calendar), "2026-11-30")
    }

    func testDaysIncludeMissingDatesAndTheirTargets() throws {
        let start = try makeDate("2026-11-02")
        let end = try makeDate("2026-11-04")

        let days = TimeReport.days(
            from: start,
            through: end,
            hoursByDay: ["2026-11-02": 7.5, "2026-11-04": 9],
            calendar: calendar,
            target: { _ in 8 }
        )

        XCTAssertEqual(days.map(\.dateKey), ["2026-11-02", "2026-11-03", "2026-11-04"])
        XCTAssertEqual(days.map(\.hours), [7.5, 0, 9])
        XCTAssertEqual(days.map(\.target), [8, 8, 8])
    }

    private func makeDate(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return try XCTUnwrap(formatter.date(from: value))
    }
}
