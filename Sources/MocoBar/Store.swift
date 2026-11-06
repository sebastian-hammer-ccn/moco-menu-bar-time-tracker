import Foundation
import SwiftUI
import ServiceManagement

@MainActor
final class Store: ObservableObject {
    @AppStorage("domain") var domain = ""
    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("projectId") var projectId = 0
    @AppStorage("taskId") var taskId = 0
    @AppStorage("dailyGoal") var dailyGoal = 8.0
    @AppStorage("menuIcon") var menuIcon = "clock"
    @AppStorage("menuShowTime") var menuShowTime = false
    @AppStorage("lunchStart") var lunchStart = 12 * 60
    @AppStorage("lunchEnd") var lunchEnd = 13 * 60
    @AppStorage("lastStopAt") var lastStopAt = 0.0
    @AppStorage("gapDay") var gapDay = ""
    @AppStorage("gapMinutes") var gapMinutes = 0
    @AppStorage("theme") var themeName = Theme.bunt.rawValue
    @AppStorage("celebratedDay") var celebratedDay = ""
    @Published var duration = ""
    @Published var note = ""
    @Published var projects: [AssignedProject] = []
    @Published var activities: [Activity] = []
    @Published var error: String?
    @Published var loading = false
    @Published var showSettings = false
    @Published var now = Date()

    private var timer: Timer?
    private var currentDay = MocoClient.today
    private var client: MocoClient { MocoClient(domain: domain.trimmingCharacters(in: .whitespaces), apiKey: apiKey.trimmingCharacters(in: .whitespaces)) }

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        Celebration.requestAuthorization()
        enableLaunchAtLogin()
        Task { await refresh(); await loadProjects() }
    }

    private func tick() {
        now = Date()
        let day = MocoClient.today
        if day != currentDay {
            currentDay = day
            Task { await refresh() }
            return
        }
        if running != nil, bookedHours >= dailyGoal, celebratedDay != day {
            celebratedDay = day
            Celebration.goalReached(hours: bookedHours)
        }
    }

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { self.error = "Autostart: \(error.localizedDescription)" }
        objectWillChange.send()
    }

    /// Beim ersten Start automatisch aktivieren; danach gilt die Wahl des Nutzers.
    private func enableLaunchAtLogin() {
        let key = "launchAtLoginInitialized"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        if SMAppService.mainApp.status != .enabled { setLaunchAtLogin(true) }
    }

    func activities(on day: String) async throws -> [Activity] {
        try await client.activities(from: day, to: day)
    }

    func updateActivity(_ id: Int, seconds: Int, description: String) async throws {
        _ = try await client.update(id, seconds: seconds, description: description)
        await refresh()
    }

    func deleteActivity(_ id: Int) async throws {
        try await client.delete(id)
        await refresh()
    }

    func mocoHoursByDay(from: String, to: String) async throws -> [String: Double] {
        var result: [String: Double] = [:]
        for a in try await client.activities(from: from, to: to) {
            if let d = a.date { result[d, default: 0] += a.hours }
        }
        return result
    }

    private func started(_ a: Activity) -> Date? {
        guard let s = a.timer_started_at else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }

    static let menuIcons = ["clock", "timer", "stopwatch", "hourglass", "briefcase", "calendar"]

    var theme: Theme { Theme(rawValue: themeName) ?? .bunt }
    var running: Activity? { activities.first { $0.timer_started_at != nil } }
    var isCheckedIn: Bool { running != nil }
    var selectedProject: AssignedProject? { projects.first { $0.id == projectId } }

    func runningSeconds(_ a: Activity) -> Double {
        guard let d = started(a) else { return 0 }
        return max(0, now.timeIntervalSince(d))
    }

    var bookedHours: Double {
        activities.reduce(0) { $0 + $1.hours + runningSeconds($1) / 3600 }
    }

    /// Noch ausstehende Mittagspause in Minuten: Rest des Mittagsfensters, außer heute wurde die Stoppuhr schon für eine Pause unterbrochen.
    var pendingLunchMinutes: Int {
        if gapDay == MocoClient.today && gapMinutes >= Store.minGapMinutes { return 0 }
        let length = lunchEnd - lunchStart
        guard length > 0 else { return 0 }
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let current = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return max(0, min(length, lunchEnd - current))
    }

    static let minGapMinutes = 15

    private func noteTimerStart() {
        defer { lastStopAt = 0 }
        guard lastStopAt > 0 else { return }
        let stop = Date(timeIntervalSince1970: lastStopAt)
        guard Calendar.current.isDateInToday(stop) else { return }
        let gap = Int(Date().timeIntervalSince(stop) / 60)
        guard gap >= Store.minGapMinutes else { return }
        gapMinutes = (gapDay == MocoClient.today ? gapMinutes : 0) + gap
        gapDay = MocoClient.today
    }

    /// Uhrzeit, zu der das Tagesziel erreicht ist: Restzeit plus noch ausstehende Pause.
    var goalReachedAt: Date? {
        let remaining = dailyGoal - bookedHours
        return remaining > 0 ? now.addingTimeInterval(remaining * 3600 + Double(pendingLunchMinutes) * 60) : nil
    }

    static func format(hours: Double) -> String {
        let m = Int((hours * 60).rounded())
        return String(format: "%d:%02d h", m / 60, m % 60)
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        do { activities = try await client.activities(); error = nil } catch { self.error = error.localizedDescription }
    }

    func loadProjects() async {
        do { projects = try await client.assignedProjects() } catch { self.error = error.localizedDescription }
    }

    // Akzeptiert "2h", "1,5h", "1:30", "90m", "45" (Minuten) 
    static func parseDuration(_ input: String) -> Int? {
        let t = input.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        if t.isEmpty { return nil }
        if t.contains(":") {
            let p = t.split(separator: ":").compactMap { Int($0) }
            return p.count == 2 ? (p[0] * 60 + p[1]) * 60 : nil
        }
        if t.hasSuffix("h"), let v = Double(t.dropLast()) { return Int(v * 3600) }
        if t.hasSuffix("m"), let v = Double(t.dropLast()) { return Int(v * 60) }
        if let v = Double(t) { return Int(v * 60) }
        return nil
    }

    var selectionValid: Bool { projectId != 0 && taskId != 0 }

    func book() async {
        guard selectionValid else { error = "Bitte Projekt und Aufgabe wählen."; return }
        guard let secs = Store.parseDuration(duration), secs > 0 else { error = "Dauer nicht lesbar (z. B. 2h, 1:30, 45m)."; return }
        loading = true
        do {
            _ = try await client.create(projectId: projectId, taskId: taskId, seconds: secs, description: note)
            duration = ""; note = ""; error = nil
        } catch { self.error = error.localizedDescription }
        await refresh()
    }

    func checkIn() async {
        guard selectionValid else { error = "Bitte Projekt und Aufgabe wählen."; return }
        loading = true
        do {
            let existing = activities.first { $0.project?.id == projectId && $0.task?.id == taskId }
            var id = existing?.id ?? 0
            if existing == nil { id = try await client.create(projectId: projectId, taskId: taskId, description: note).id }
            noteTimerStart()
            _ = try await client.startTimer(id)
            error = nil
        } catch { self.error = error.localizedDescription }
        await refresh()
    }

    func checkOut() async {
        guard let r = running else { return }
        loading = true
        do { _ = try await client.stopTimer(r.id); lastStopAt = Date().timeIntervalSince1970; error = nil } catch { self.error = error.localizedDescription }
        await refresh()
    }
}
