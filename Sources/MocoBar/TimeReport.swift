import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }
    var title: String { self == .week ? "Woche" : "Monat" }

    func interval(containing date: Date, calendar: Calendar) -> DateInterval? {
        calendar.dateInterval(of: self == .week ? .weekOfYear : .month, for: date)
    }

    func shifted(_ date: Date, by amount: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: self == .week ? .weekOfYear : .month, value: amount, to: date) ?? date
    }
}

struct ReportDay: Identifiable {
    let date: Date
    let dateKey: String
    let hours: Double
    let target: Double

    var id: String { dateKey }
}

enum TimeReport {
    static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    static func days(
        from start: Date,
        through end: Date,
        hoursByDay: [String: Double],
        calendar: Calendar,
        target: (Date) -> Double
    ) -> [ReportDay] {
        var result: [ReportDay] = []
        var date = calendar.startOfDay(for: start)
        let finalDate = calendar.startOfDay(for: end)
        while date <= finalDate {
            let key = isoDate(date, calendar: calendar)
            result.append(ReportDay(
                date: date,
                dateKey: key,
                hours: hoursByDay[key] ?? 0,
                target: target(date)
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }
}
