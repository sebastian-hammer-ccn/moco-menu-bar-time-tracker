import SwiftUI

@MainActor
final class HistoryModel: ObservableObject {
    @Published var date = Calendar.current.startOfDay(for: Date())
    @Published var activities: [Activity] = []
    @Published var loading = false
    @Published var error: String?
    @Published var editingId: Int?
    @Published var editDuration = ""
    @Published var editNote = ""
}

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @StateObject private var m = HistoryModel()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var total: Double { m.activities.reduce(0) { $0 + $1.hours } }
    private var isToday: Bool { Calendar.current.isDateInToday(m.date) }

    private func shift(_ days: Int) {
        m.date = Calendar.current.date(byAdding: .day, value: days, to: m.date) ?? m.date
    }

    var body: some View {
        let t = store.theme
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.borderless)
                DatePicker("", selection: $m.date, in: ...Date(), displayedComponents: .date).labelsHidden()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless).disabled(isToday)
                Button("Heute") { m.date = Calendar.current.startOfDay(for: Date()) }.disabled(isToday)
                Spacer()
                if m.loading { ProgressView().controlSize(.small) }
            }
            .foregroundStyle(t.text)

            Text(m.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(t.text)

            if let error = m.error {
                Text(error).font(.caption).foregroundStyle(.white).padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.7)))
            }

            Card {
                if m.activities.isEmpty {
                    Text(m.loading ? "Lädt …" : "Keine Buchungen an diesem Tag.")
                        .font(.callout).foregroundStyle(t.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(m.activities) { a in
                                if m.editingId == a.id { editor(a) } else { row(a) }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            HStack {
                Text("Summe").font(.callout.weight(.semibold))
                Spacer()
                Text(Store.format(hours: total)).font(.title3.monospacedDigit().weight(.bold))
            }
            .foregroundStyle(t.text)
        }
        .padding(14)
        .frame(minWidth: 400, idealWidth: 420, minHeight: 360, idealHeight: 460)
        .themed(t)
        .task(id: m.date) { await load() }
    }

    private func row(_ a: Activity) -> some View {
        let t = store.theme
        let editable = store.running?.id != a.id
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(a.project?.name ?? "–").font(.callout.weight(.semibold)).lineLimit(1).foregroundStyle(t.text)
                Text([a.task?.name, a.description].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(t.secondaryText).lineLimit(2)
            }
            Spacer()
            Text(Store.format(hours: a.hours)).font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(t.text)
            if editable {
                Button { startEditing(a) } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText)
            }
        }
    }

    private func editor(_ a: Activity) -> some View {
        let t = store.theme
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(a.project?.name ?? "–") · \(a.task?.name ?? "–")").font(.callout.weight(.semibold)).foregroundStyle(t.text).lineLimit(1)
            HStack(spacing: 8) {
                Field(icon: "timer", tint: .blue) { TextField("2h", text: $m.editDuration).textFieldStyle(.plain) }.frame(width: 110)
                Field(icon: "text.alignleft", tint: .teal) { TextField("Notiz", text: $m.editNote).textFieldStyle(.plain) }
            }
            HStack(spacing: 8) {
                Button { Task { await save(a) } } label: { Label("Speichern", systemImage: "checkmark") }
                    .buttonStyle(FilledButtonStyle(theme: t, color: .green))
                Button { Task { await remove(a) } } label: { Label("Löschen", systemImage: "trash") }
                    .buttonStyle(FilledButtonStyle(theme: t, color: .red))
                Button { m.editingId = nil } label: { Label("Abbrechen", systemImage: "xmark") }
                    .buttonStyle(FilledButtonStyle(theme: t, color: .gray))
            }
        }
    }

    private func startEditing(_ a: Activity) {
        m.editingId = a.id
        m.editDuration = Store.format(hours: a.hours).replacingOccurrences(of: " h", with: "")
        m.editNote = a.description ?? ""
    }

    private func save(_ a: Activity) async {
        guard let secs = Store.parseDuration(m.editDuration), secs >= 0 else { m.error = "Dauer nicht lesbar (z. B. 2h, 1:30, 45m)."; return }
        do {
            try await store.updateActivity(a.id, seconds: secs, description: m.editNote)
            m.editingId = nil
            await load()
        } catch { m.error = error.localizedDescription }
    }

    private func remove(_ a: Activity) async {
        do {
            try await store.deleteActivity(a.id)
            m.editingId = nil
            await load()
        } catch { m.error = error.localizedDescription }
    }

    private func load() async {
        m.editingId = nil
        m.loading = true
        defer { m.loading = false }
        let day = Self.dayFormatter.string(from: m.date)
        do {
            let result = try await store.activities(on: day)
            m.activities = result
            m.error = nil
        } catch is CancellationError {
        } catch let e as URLError where e.code == .cancelled {
        } catch { m.error = error.localizedDescription; m.activities = [] }
    }
}
