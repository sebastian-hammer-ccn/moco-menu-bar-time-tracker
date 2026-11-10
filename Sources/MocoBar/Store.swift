import Foundation
import SwiftUI
import ServiceManagement

struct TimeFavorite: Codable, Identifiable, Equatable {
    let id: String
    let projectId: Int
    let taskId: Int
    let projectName: String
    let taskName: String
    let note: String
}

@MainActor
final class Store: ObservableObject {
    @AppStorage("domain") var domain = ""
    @AppStorage("timeFavorites") private var timeFavoritesRaw = "[]"
    @AppStorage("projectId") var projectId = 0
    @AppStorage("taskId") var taskId = 0
    @AppStorage("dailyGoal") var dailyGoal = 8.0
    @AppStorage("menuIcon") var menuIcon = "clock"
    @AppStorage("menuShowTime") var menuShowTime = false
    @AppStorage("menuDisplay") var menuDisplayRaw = ""
    @AppStorage("weekdayGoalsOn") var weekdayGoalsOn = false
    @AppStorage("weekdayGoals") var weekdayGoalsRaw = ""

    enum MenuDisplay: String, CaseIterable, Identifiable {
        case none, running, worked, remaining
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: "Nur Icon"
            case .running: "Laufende Zeit"
            case .worked: "Gearbeitet + %"
            case .remaining: "Noch bis Feierabend"
            }
        }
    }

    var menuDisplay: MenuDisplay {
        get { MenuDisplay(rawValue: menuDisplayRaw) ?? (menuShowTime ? .running : .none) }
        set { menuDisplayRaw = newValue.rawValue }
    }

    var menuText: String? {
        switch menuDisplay {
        case .none: return nil
        case .running: return running.map { Store.format(hours: runningSeconds($0) / 3600) }
        case .worked:
            let pct = Int(bookedHours / max(goalToday, 0.1) * 100)
            return "\(Store.format(hours: bookedHours)) · \(pct) %"
        case .remaining:
            let rest = goalToday - bookedHours
            return rest > 0 ? "noch " + Store.format(hours: rest) : "+" + Store.format(hours: -rest)
        }
    }

    static let weekdayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    /// Tagesziele Montag bis Sonntag; ohne gespeicherte Werte gilt das Tagesziel für Mo–Fr.
    var weekdayGoals: [Double] {
        let parsed = weekdayGoalsRaw.split(separator: ",", omittingEmptySubsequences: false).map { Double($0) }
        return (0..<7).map { i in
            if i < parsed.count, let v = parsed[i] { return v }
            return i < 5 ? dailyGoal : 0
        }
    }

    func setWeekdayGoal(_ index: Int, _ value: Double) {
        var g = weekdayGoals
        g[index] = max(0, value)
        weekdayGoalsRaw = g.map { String($0) }.joined(separator: ",")
    }

    var goalToday: Double {
        goal(on: now)
    }

    func goal(on date: Date) -> Double {
        guard weekdayGoalsOn else { return dailyGoal }
        return weekdayGoals[(Calendar.current.component(.weekday, from: date) + 5) % 7]
    }
    @AppStorage("lunchStart") var lunchStart = 12 * 60
    @AppStorage("lunchEnd") var lunchEnd = 13 * 60
    @AppStorage("lastStopAt") var lastStopAt = 0.0
    @AppStorage("gapDay") var gapDay = ""
    @AppStorage("gapMinutes") var gapMinutes = 0
    @AppStorage("theme") var themeName = Theme.bunt.rawValue
    @AppStorage("celebratedDay") var celebratedDay = ""
    @Published var duration = ""
    @Published var note = ""
    @Published var apiKey = ""
    @Published var projects: [AssignedProject] = []
    @Published var activities: [Activity] = []
    @Published var error: String?
    @Published var credentialError: String?
    @Published var loading = false
    @Published var showSettings = false
    @Published var now = Date()

    private var timer: Timer?
    private var currentDay = MocoClient.today
    private var client: MocoClient { MocoClient(domain: domain.trimmingCharacters(in: .whitespaces), apiKey: apiKey.trimmingCharacters(in: .whitespaces)) }

    var favorites: [TimeFavorite] {
        get {
            guard let data = timeFavoritesRaw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([TimeFavorite].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8) else { return }
            timeFavoritesRaw = encoded
        }
    }

    init() {
        loadAPIKey()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        Celebration.requestAuthorization()
        enableLaunchAtLogin()
        Task { await refresh(); await loadProjects() }
    }

    private func loadAPIKey() {
        do {
            if let stored = try KeychainStore.load() {
                apiKey = stored
                UserDefaults.standard.removeObject(forKey: "apiKey")
            } else if let legacy = UserDefaults.standard.string(forKey: "apiKey"), !legacy.isEmpty {
                try KeychainStore.save(legacy)
                apiKey = legacy
                UserDefaults.standard.removeObject(forKey: "apiKey")
            }
        } catch {
            credentialError = error.localizedDescription
        }
    }

    @discardableResult
    func setAPIKey(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if value.isEmpty {
                try KeychainStore.delete()
            } else {
                try KeychainStore.save(value)
            }
            apiKey = value
            UserDefaults.standard.removeObject(forKey: "apiKey")
            credentialError = nil
            return true
        } catch {
            credentialError = error.localizedDescription
            return false
        }
    }

    func addFavorite() {
        guard selectionValid,
              let project = selectedProject,
              let task = project.tasks.first(where: { $0.id == taskId }) else { return }
        let favorite = TimeFavorite(
            id: UUID().uuidString,
            projectId: project.id,
            taskId: task.id,
            projectName: project.name,
            taskName: task.name,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        var saved = favorites
        if let index = saved.firstIndex(where: {
            $0.projectId == favorite.projectId && $0.taskId == favorite.taskId && $0.note == favorite.note
        }) {
            saved[index] = TimeFavorite(
                id: saved[index].id,
                projectId: favorite.projectId,
                taskId: favorite.taskId,
                projectName: favorite.projectName,
                taskName: favorite.taskName,
                note: favorite.note
            )
        } else {
            saved.append(favorite)
        }
        favorites = saved
    }

    func removeFavorite(_ favorite: TimeFavorite) {
        favorites = favorites.filter { $0.id != favorite.id }
    }

    func startFavorite(_ favorite: TimeFavorite) async {
        guard let project = projects.first(where: { $0.id == favorite.projectId }),
              project.tasks.contains(where: { $0.id == favorite.taskId }) else {
            error = "Der Favorit ist nicht mehr verfügbar. Bitte Projekte neu laden."
            return
        }
        projectId = favorite.projectId
        taskId = favorite.taskId
        note = favorite.note
        await checkIn()
    }

    private func tick() {
        now = Date()
        let day = MocoClient.today
        if day != currentDay {
            currentDay = day
            Task { await refresh() }
            return
        }
        if running != nil, goalToday > 0, bookedHours >= goalToday, celebratedDay != day {
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
            if let d = a.date {
                result[d, default: 0] += a.hours
                if a.timer_started_at != nil { result[d, default: 0] += runningSeconds(a) / 3600 }
            }
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
        let remaining = goalToday - bookedHours
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
