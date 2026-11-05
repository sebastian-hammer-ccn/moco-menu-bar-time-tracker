import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ReconcileModel: ObservableObject {
    @Published var fileName: String?
    @Published var excel: [ExcelDay] = []
    @Published var moco: [String: Double] = [:]
    @Published var includeAbsence = true
    @Published var loading = false
    @Published var error: String?
    @Published var importing = false
}

struct ReconcileView: View {
    @EnvironmentObject var store: Store
    @StateObject private var m = ReconcileModel()

    private var rows: [ReconcileRow] { ExcelImport.compare(excel: m.excel, moco: m.moco, includeAbsence: m.includeAbsence) }

    var body: some View {
        let t = store.theme
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Excel wählen …") { m.importing = true }
                if let fileName = m.fileName { Text(fileName).font(.caption).foregroundStyle(t.secondaryText).lineLimit(1) }
                Spacer()
                if m.loading { ProgressView().controlSize(.small) }
            }
            Toggle("Abwesenheit (ABW, z. B. Gleitzeitabbau) zur Sollzeit zählen", isOn: $m.includeAbsence).font(.caption)

            if let error = m.error {
                Text(error).font(.caption).foregroundStyle(.white).padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.7)))
            }

            if m.excel.isEmpty {
                Text("Monatsexport des Zeiterfassungssystems auswählen. Die Zeiten werden pro Tag mit den in Moco gebuchten Stunden verglichen.")
                    .font(.callout).foregroundStyle(t.secondaryText)
                Spacer()
            } else {
                summary
                List(rows) { row in line(row) }
                    .listStyle(.plain)
            }
        }
        .padding(14)
        .frame(minWidth: 520, minHeight: 360)
        .themed(t)
        .fileImporter(isPresented: $m.importing, allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data]) { result in
            if case .success(let url) = result { Task { await load(url) } }
        }
    }

    private var summary: some View {
        let problems = rows.filter { $0.status != .ok }
        let excelTotal = rows.reduce(0) { $0 + $1.excel }
        let mocoTotal = rows.reduce(0) { $0 + $1.moco }
        return HStack(spacing: 16) {
            Label(problems.isEmpty ? "Alles stimmt" : "\(problems.count) Abweichung\(problems.count == 1 ? "" : "en")",
                  systemImage: problems.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(problems.isEmpty ? .green : .orange)
                .font(.headline)
            Spacer()
            Text("Excel \(Store.format(hours: excelTotal))  ·  Moco \(Store.format(hours: mocoTotal))")
                .font(.caption.monospacedDigit()).foregroundStyle(store.theme.secondaryText)
        }
    }

    private func line(_ r: ReconcileRow) -> some View {
        let (icon, color, text) = describe(r)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label(r.date)).font(.body.weight(.medium))
                if !r.spans.isEmpty { Text(r.spans.joined(separator: ", ")).font(.caption).foregroundStyle(store.theme.secondaryText) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Excel \(Store.format(hours: r.excel))  Moco \(Store.format(hours: r.moco))").font(.caption.monospacedDigit())
                if let text { Text(text).font(.caption.weight(.semibold)).foregroundStyle(color) }
            }
        }
        .padding(.vertical, 2)
    }

    private func describe(_ r: ReconcileRow) -> (String, Color, String?) {
        switch r.status {
        case .ok: return ("checkmark.circle.fill", .green, nil)
        case .tooLittle: return ("minus.circle.fill", .orange, "\(Store.format(hours: -r.diff)) fehlen in Moco")
        case .tooMuch: return ("plus.circle.fill", .orange, "\(Store.format(hours: r.diff)) zu viel in Moco")
        case .missingInMoco: return ("xmark.circle.fill", .red, "nichts in Moco gebucht")
        case .onlyInMoco: return ("questionmark.circle.fill", .red, "nur in Moco, nicht im Excel")
        }
    }

    private func label(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: iso) else { return iso }
        f.dateFormat = "EEEE, dd.MM.yyyy"
        return f.string(from: d)
    }

    private func load(_ url: URL) async {
        m.error = nil
        m.loading = true
        defer { m.loading = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let days = try ExcelImport.read(url)
            let from = days.first!.date, to = days.last!.date
            m.moco = try await store.mocoHoursByDay(from: from, to: to)
            m.excel = days
            m.fileName = url.lastPathComponent
        } catch {
            m.error = error.localizedDescription
        }
    }
}
