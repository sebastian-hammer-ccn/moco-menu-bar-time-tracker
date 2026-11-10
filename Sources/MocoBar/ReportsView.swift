import SwiftUI

@MainActor
final class ReportsModel: ObservableObject {
    @Published var period: ReportPeriod = .week
    @Published var anchor = Date()
    @Published var days: [ReportDay] = []
    @Published var loading = false
    @Published var error: String?

    var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    var requestID: String {
        "\(period.rawValue)-\(TimeReport.isoDate(anchor, calendar: calendar))"
    }
}

struct ReportsView: View {
    @EnvironmentObject private var store: Store
    @StateObject private var model = ReportsModel()

    private var currentInterval: DateInterval? {
        model.period.interval(containing: Date(), calendar: model.calendar)
    }

    private var selectedInterval: DateInterval? {
        model.period.interval(containing: model.anchor, calendar: model.calendar)
    }

    private var isCurrentPeriod: Bool {
        guard let current = currentInterval, let selected = selectedInterval else { return true }
        return selected.start >= current.start
    }

    private var totalHours: Double { model.days.reduce(0) { $0 + $1.hours } }
    private var totalTarget: Double { model.days.reduce(0) { $0 + $1.target } }
    private var difference: Double { totalHours - totalTarget }

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 12) {
            header
            Picker("Zeitraum", selection: $model.period) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)

            periodNavigator

            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.white).padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.7)))
            }

            summary

            Card {
                if model.days.isEmpty {
                    Text(model.loading ? "Lädt …" : "Keine Tage in diesem Zeitraum.")
                        .font(.callout).foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(model.days) { day in
                                dayRow(day)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 460, idealHeight: 560)
        .themed(theme)
        .task(id: model.requestID) { await load() }
    }

    private var header: some View {
        let theme = store.theme
        return HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis").font(.title2).foregroundStyle(theme.tint(.blue))
            Text("Arbeitszeitübersicht").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(theme.text)
            Spacer()
            if model.loading { ProgressView().controlSize(.small) }
        }
    }

    private var periodNavigator: some View {
        let theme = store.theme
        return HStack(spacing: 12) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Spacer()
            Text(periodTitle)
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .disabled(isCurrentPeriod)
        }
        .foregroundStyle(theme.secondaryText)
    }

    private var periodTitle: String {
        guard let interval = selectedInterval,
              let lastDay = model.calendar.date(byAdding: .day, value: -1, to: interval.end) else { return "" }
        if model.period == .month {
            return interval.start.formatted(.dateTime.month(.wide).year())
        }
        return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(lastDay.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    private var summary: some View {
        let theme = store.theme
        let progress = totalTarget > 0 ? min(1, totalHours / totalTarget) : (totalHours > 0 ? 1 : 0)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Store.format(hours: totalHours))
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                Text("gearbeitet").font(.caption).opacity(0.8)
                Spacer()
                Text(difference >= 0 ? "+\(Store.format(hours: difference))" : "−\(Store.format(hours: -difference))")
                    .font(.callout.weight(.semibold).monospacedDigit())
            }
            ProgressView(value: progress).tint(theme.isColorful ? .white : theme.accent)
            HStack {
                Text("Soll: \(Store.format(hours: totalTarget))")
                Spacer()
                Text("\(model.days.count) \(model.days.count == 1 ? "Tag" : "Tage")")
            }
            .font(.caption2).opacity(0.8)
        }
        .foregroundStyle(theme.summaryText)
        .padding(14)
        .background(
            Group {
                if theme.isColorful {
                    shape.fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(theme.cardFill)
                }
            }
        )
        .overlay(shape.stroke(theme.isColorful ? Color.clear : theme.border))
    }

    private func dayRow(_ day: ReportDay) -> some View {
        let theme = store.theme
        let progress = day.target > 0 ? min(1, day.hours / day.target) : (day.hours > 0 ? 1 : 0)
        return VStack(spacing: 4) {
            HStack {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.callout.weight(.medium)).foregroundStyle(theme.text)
                Spacer()
                Text(Store.format(hours: day.hours))
                    .font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(theme.text)
            }
            ProgressView(value: progress).tint(day.target > 0 && day.hours >= day.target ? .green : theme.accent)
            HStack {
                Text("Soll \(Store.format(hours: day.target))")
                Spacer()
                let delta = day.hours - day.target
                Text(delta >= 0 ? "+\(Store.format(hours: delta))" : "−\(Store.format(hours: -delta))")
            }
            .font(.caption2).foregroundStyle(theme.secondaryText)
        }
    }

    private func shift(_ amount: Int) {
        model.anchor = model.period.shifted(model.anchor, by: amount, calendar: model.calendar)
    }

    private func load() async {
        guard let interval = selectedInterval,
              let lastDay = model.calendar.date(byAdding: .day, value: -1, to: interval.end) else { return }
        let today = model.calendar.startOfDay(for: Date())
        let end = min(lastDay, today)
        guard end >= interval.start else {
            model.days = []
            return
        }

        model.loading = true
        model.error = nil
        defer { model.loading = false }
        do {
            let from = TimeReport.isoDate(interval.start, calendar: model.calendar)
            let to = TimeReport.isoDate(end, calendar: model.calendar)
            let hours = try await store.mocoHoursByDay(from: from, to: to)
            model.days = TimeReport.days(
                from: interval.start,
                through: end,
                hoursByDay: hours,
                calendar: model.calendar,
                target: { store.goal(on: $0) }
            )
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            model.error = error.localizedDescription
            model.days = []
        }
    }
}
