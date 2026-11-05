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
            header
            if let error = m.error {
                Text(error).font(.caption).foregroundStyle(.white).padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.7)))
            }
            if m.excel.isEmpty {
                Card {
                    Text("Monatsexport des Zeiterfassungssystems auswählen. Die Zeiten werden pro Tag mit den in Moco gebuchten Stunden verglichen.")
                        .font(.callout).foregroundStyle(t.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            } else {
                summary
                Card {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(rows) { r in line(r) }
                        }
                    }
                }
            }
            Toggle("Abwesenheit (ABW, z. B. Gleitzeitabbau) zur Sollzeit zählen", isOn: $m.includeAbsence)
                .font(.caption).foregroundStyle(t.secondaryText)
            Button { m.importing = true } label: { Label(m.excel.isEmpty ? "GFOS-Export wählen" : "Anderen GFOS-Export wählen", systemImage: "doc.badge.plus") }
                .buttonStyle(FilledButtonStyle(theme: t, color: t.isColorful ? .blue : t.accent))
        }
        .padding(14)
        .frame(minWidth: 440, idealWidth: 460, minHeight: 420, idealHeight: 560)
        .themed(t)
        .fileImporter(isPresented: $m.importing, allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data]) { result in
            if case .success(let url) = result { Task { await load(url) } }
        }
    }

    private var header: some View {
        let t = store.theme
        return HStack(spacing: 8) {
            Image(systemName: "checklist").font(.title2).foregroundStyle(t.tint(.blue))
            Text("Zeitabgleich").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(t.text)
            Spacer()
            if m.loading { ProgressView().controlSize(.small) }
        }
    }

    private var monthExcel: Double { rows.reduce(0) { $0 + $1.excel } }
    private var monthMoco: Double { rows.reduce(0) { $0 + $1.moco } }
    private var monthMatches: Bool { abs(monthMoco - monthExcel) <= 0.05 }

    private var summary: some View {
        let t = store.theme
        let problems = rows.filter { $0.status != .ok }
        let excelTotal = monthExcel
        let mocoTotal = monthMoco
        let good = monthMatches
        let monthDiff = mocoTotal - excelTotal
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(good ? "Monat stimmt" : Store.format(hours: abs(monthDiff)))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                if !good { Text(monthDiff < 0 ? "fehlen in Moco" : "zu viel in Moco").font(.caption).opacity(0.8) }
                Spacer()
                Image(systemName: good ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").font(.title2)
            }
            ProgressView(value: min(1, mocoTotal / max(excelTotal, 0.1)))
                .tint(t.isColorful ? .white : (good ? .green : .orange))
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Moco gesamt").font(.caption2).opacity(0.8)
                    Text(Store.format(hours: mocoTotal)).font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("GFOS gesamt").font(.caption2).opacity(0.8)
                    Text(Store.format(hours: excelTotal)).font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                }
            }
            if good && !problems.isEmpty {
                Text("\(problems.count) Tagesabweichung\(problems.count == 1 ? "" : "en") ignoriert, da die Monatsstunden passen")
                    .font(.caption2).opacity(0.8)
            } else if !good && !problems.isEmpty {
                Text("\(problems.count) Tag\(problems.count == 1 ? "" : "e") mit Abweichung")
                    .font(.caption2).opacity(0.8)
            }
        }
        .foregroundStyle(t.summaryText)
        .padding(14)
        .background(
            Group {
                if t.isColorful {
                    shape.fill(LinearGradient(colors: good ? [.green, .teal] : [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(t.cardFill)
                }
            }
        )
        .overlay(shape.stroke(t.isColorful ? Color.clear : t.border))
    }

    private func line(_ r: ReconcileRow) -> some View {
        let t = store.theme
        let (icon, color, text) = monthMatches ? describe(ReconcileRow(date: r.date, excel: r.excel, absence: r.absence, moco: r.moco, spans: r.spans, status: .ok)) : describe(r)
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(t.tint(color)).frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(label(r.date)).font(.callout.weight(.semibold)).lineLimit(1).foregroundStyle(t.text)
                Text(r.spans.isEmpty ? "keine Zeiten in GFOS" : r.spans.joined(separator: " · "))
                    .font(.caption).foregroundStyle(t.secondaryText).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let text {
                    Text(text).font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(color))
                } else {
                    Image(systemName: icon).foregroundStyle(color)
                }
                Text("GFOS \(Store.format(hours: r.excel)) · Moco \(Store.format(hours: r.moco))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(t.secondaryText)
            }
        }
    }

    private func describe(_ r: ReconcileRow) -> (String, Color, String?) {
        switch r.status {
        case .ok: return ("checkmark.circle.fill", .green, nil)
        case .tooLittle: return ("minus.circle.fill", .orange, "\(Store.format(hours: -r.diff)) fehlen")
        case .tooMuch: return ("plus.circle.fill", .orange, "\(Store.format(hours: r.diff)) zu viel")
        case .missingInMoco: return ("xmark.circle.fill", .red, "nicht gebucht")
        case .onlyInMoco: return ("questionmark.circle.fill", .red, "nur in Moco")
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
