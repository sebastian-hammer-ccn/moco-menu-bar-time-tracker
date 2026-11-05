import Foundation

struct ExcelDay: Identifiable {
    var id: String { date }
    let date: String
    var worked: Double = 0
    var absence: Double = 0
    var spans: [String] = []
    var segments: [(from: Double, to: Double, hours: Double)] = []

    /// Uhrzeit (in Minuten ab Mitternacht), zu der `target` Stunden erreicht sind, wenn nach dem letzten Gehen keine Pause mehr folgt.
    func reachMinutes(target: Double) -> Int? {
        guard target > 0, !segments.isEmpty else { return nil }
        var sum = 0.0
        for s in segments {
            if sum + s.hours >= target - 0.0001 {
                return Int(((s.to * 24 - (sum + s.hours - target)) * 60).rounded())
            }
            sum += s.hours
        }
        guard let last = segments.last else { return nil }
        return Int(((last.to * 24 + (target - sum)) * 60).rounded())
    }
}

enum ReconcileStatus { case ok, tooLittle, tooMuch, missingInMoco, onlyInMoco }

struct ReconcileRow: Identifiable {
    var id: String { date }
    let date: String
    let excel: Double
    let absence: Double
    let moco: Double
    let spans: [String]
    var reachAt: String? = nil
    let status: ReconcileStatus
    var diff: Double { moco - excel }
}

enum ExcelError: LocalizedError {
    case unreadable, noData
    var errorDescription: String? {
        switch self {
        case .unreadable: return "Die GFOS-Datei konnte nicht gelesen werden."
        case .noData: return "Keine Zeitbuchungen (Typ LES/ABW) in der Datei gefunden."
        }
    }
}

enum ExcelImport {
    static func read(_ url: URL) throws -> [ExcelDay] {
        guard let shared = unzip(url, "xl/sharedStrings.xml"), let sheet = unzip(url, "xl/worksheets/sheet1.xml") else { throw ExcelError.unreadable }
        let strings = SharedStrings.parse(shared)
        let rows = SheetRows.parse(sheet, strings: strings)
        guard let header = rows.first else { throw ExcelError.noData }
        func col(_ name: String) -> String? { header.first { $0.value == name }?.key }
        guard let dateCol = col("Datum"), let typeCol = col("Typ"), let istCol = col("Ist"),
              let fromCol = col("Kommen"), let toCol = col("Gehen") else { throw ExcelError.unreadable }

        var days: [String: ExcelDay] = [:]
        var current: String?
        for row in rows.dropFirst() {
            if let s = row[dateCol], let serial = Double(s) { current = isoDate(serial: serial) }
            guard let date = current else { continue }
            let type = row[typeCol] ?? ""
            let ist = Double(row[istCol] ?? "") ?? 0
            var day = days[date] ?? ExcelDay(date: date)
            switch type {
            case "LES":
                day.worked += ist
                if let a = Double(row[fromCol] ?? ""), let b = Double(row[toCol] ?? "") {
                    day.spans.append("\(clock(a))-\(clock(b))")
                    day.segments.append((from: a, to: b, hours: ist))
                }
            case "ABW": day.absence += ist
            default: break
            }
            days[date] = day
        }
        let result = days.values.filter { $0.worked > 0 || $0.absence > 0 }.sorted { $0.date < $1.date }
        if result.isEmpty { throw ExcelError.noData }
        return result
    }

    static func compare(excel: [ExcelDay], moco: [String: Double], includeAbsence: Bool, dailyGoal: Double = 8, tolerance: Double = 0.02) -> [ReconcileRow] {
        var rows: [ReconcileRow] = []
        let excelDates = Set(excel.map(\.date))
        for d in excel {
            let expected = d.worked + (includeAbsence ? d.absence : 0)
            let booked = moco[d.date] ?? 0
            let status: ReconcileStatus
            if abs(booked - expected) <= tolerance { status = .ok }
            else if booked == 0 { status = .missingInMoco }
            else if booked < expected { status = .tooLittle }
            else { status = .tooMuch }
            let reach = d.reachMinutes(target: dailyGoal - (includeAbsence ? d.absence : 0)).map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
            rows.append(ReconcileRow(date: d.date, excel: expected, absence: d.absence, moco: booked, spans: d.spans, reachAt: reach, status: status))
        }
        for (date, hours) in moco where !excelDates.contains(date) && hours > tolerance {
            rows.append(ReconcileRow(date: date, excel: 0, absence: 0, moco: hours, spans: [], status: .onlyInMoco))
        }
        return rows.sorted { $0.date < $1.date }
    }

    private static func unzip(_ url: URL, _ entry: String) -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-p", url.path, entry]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 && !data.isEmpty ? data : nil
    }

    private static func isoDate(serial: Double) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let base = cal.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        let d = cal.date(byAdding: .day, value: Int(serial.rounded(.down)), to: base)!
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private static func clock(_ fraction: Double) -> String {
        let minutes = Int((fraction * 24 * 60).rounded())
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

private final class SharedStrings: NSObject, XMLParserDelegate {
    var items: [String] = []
    private var text = ""
    private var inT = false
    static func parse(_ data: Data) -> [String] {
        let h = SharedStrings()
        let p = XMLParser(data: data)
        p.delegate = h
        p.parse()
        return h.items
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "si" { text = "" }
        if name == "t" { inT = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inT { text += string } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "t" { inT = false }
        if name == "si" { items.append(text) }
    }
}

private final class SheetRows: NSObject, XMLParserDelegate {
    var rows: [[String: String]] = []
    private var strings: [String] = []
    private var row: [String: String] = [:]
    private var ref = "", type = "", value = ""
    private var inV = false
    static func parse(_ data: Data, strings: [String]) -> [[String: String]] {
        let h = SheetRows()
        h.strings = strings
        let p = XMLParser(data: data)
        p.delegate = h
        p.parse()
        return h.rows
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch name {
        case "row": row = [:]
        case "c": ref = String(attributes["r"]?.prefix { $0.isLetter } ?? ""); type = attributes["t"] ?? ""; value = ""
        case "v": inV = true
        default: break
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inV { value += string } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "v": inV = false
        case "c":
            if type == "s", let i = Int(value), i < strings.count { row[ref] = strings[i] }
            else if !value.isEmpty { row[ref] = value }
        case "row": rows.append(row)
        default: break
        }
    }
}
