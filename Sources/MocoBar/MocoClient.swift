import Foundation

struct AssignedTask: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let active: Bool?
}

struct AssignedProject: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let tasks: [AssignedTask]
}

struct Activity: Decodable, Identifiable {
    struct Named: Decodable { let id: Int?; let name: String }
    let id: Int
    let hours: Double
    let timer_started_at: String?
    let description: String?
    let project: Named?
    let task: Named?
}

enum MocoError: LocalizedError {
    case notConfigured, http(Int, String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Bitte Domain und API-Key in den Einstellungen eintragen."
        case .http(let c, let m): return "Moco-Fehler \(c): \(m)"
        }
    }
}

struct MocoClient {
    let domain: String
    let apiKey: String

    private func request<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], body: [String: Any]? = nil) async throws -> T {
        var d = domain.lowercased()
        for junk in ["https://", "http://", ".mocoapp.com", "/"] { d = d.replacingOccurrences(of: junk, with: "") }
        guard !d.isEmpty, !apiKey.isEmpty else { throw MocoError.notConfigured }
        var comps = URLComponents(string: "https://\(d).mocoapp.com/api/v1\(path)")!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("Token token=\(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw MocoError.http(code, "\(method) \(comps.url!.absoluteString) \(String(data: data, encoding: .utf8) ?? "")")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    func activities() async throws -> [Activity] {
        try await request("GET", "/activities", query: ["from": Self.today, "to": Self.today])
    }

    func assignedProjects() async throws -> [AssignedProject] {
        try await request("GET", "/projects/assigned", query: ["active": "true"])
    }

    func create(projectId: Int, taskId: Int, seconds: Int = 0, description: String = "") async throws -> Activity {
        try await request("POST", "/activities", body: ["date": Self.today, "project_id": projectId, "task_id": taskId, "hours": Double(seconds) / 3600, "description": description])
    }

    func startTimer(_ id: Int) async throws -> Activity { try await request("PATCH", "/activities/\(id)/start_timer") }
    func stopTimer(_ id: Int) async throws -> Activity { try await request("PATCH", "/activities/\(id)/stop_timer") }
}
