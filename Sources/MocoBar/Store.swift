import Foundation
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @AppStorage("domain") var domain = ""
    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("projectId") var projectId = 0
    @AppStorage("taskId") var taskId = 0
    @AppStorage("dailyGoal") var dailyGoal = 8.0
    @AppStorage("theme") var themeName = Theme.bunt.rawValue
    @Published var duration = ""
    @Published var note = ""
    @Published var projects: [AssignedProject] = []
    @Published var activities: [Activity] = []
    @Published var error: String?
    @Published var loading = false
    @Published var showSettings = false
    @Published var now = Date()

    private var timer: Timer?
    private var client: MocoClient { MocoClient(domain: domain.trimmingCharacters(in: .whitespaces), apiKey: apiKey.trimmingCharacters(in: .whitespaces)) }

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        Task { await refresh(); await loadProjects() }
    }

    private func started(_ a: Activity) -> Date? {
        guard let s = a.timer_started_at else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }

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
            _ = try await client.startTimer(id)
            error = nil
        } catch { self.error = error.localizedDescription }
        await refresh()
    }

    func checkOut() async {
        guard let r = running else { return }
        loading = true
        do { _ = try await client.stopTimer(r.id); error = nil } catch { self.error = error.localizedDescription }
        await refresh()
    }
}
