import SwiftUI

@main
struct MocoBarApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.menuIcon).symbolVariant(store.isCheckedIn ? .fill : .none)
                if let text = store.menuText { Text(text) }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Moco-Einstellungen", id: "settings") {
            SettingsView().environmentObject(store)
        }
        .windowResizability(.contentSize)

        Window("Gebuchte Zeiten", id: "history") {
            HistoryView().environmentObject(store)
        }
        .defaultSize(width: 420, height: 460)

        Window("Zeitabgleich", id: "reconcile") {
            ReconcileView().environmentObject(store)
        }
        .defaultSize(width: 480, height: 660)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 10) {
            Field(icon: "globe", tint: .blue) { TextField("Moco-Domain (z. B. firma)", text: store.$domain).textFieldStyle(.plain) }
            Field(icon: "key.fill", tint: .orange) { SecureField("API-Key", text: store.$apiKey).textFieldStyle(.plain) }
            Field(icon: "target", tint: .green) {
                Text("Tagesziel (Stunden)")
                Spacer()
                TextField("8", value: store.$dailyGoal, format: .number).textFieldStyle(.plain).frame(width: 50).multilineTextAlignment(.trailing)
            }
            Field(icon: "calendar", tint: .green) {
                Text("Ziel pro Wochentag").lineLimit(1)
                Spacer()
                Toggle("", isOn: store.$weekdayGoalsOn).toggleStyle(.switch).labelsHidden()
            }
            if store.weekdayGoalsOn {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 2) {
                            Text(Store.weekdayNames[i]).font(.caption2).foregroundStyle(theme.secondaryText)
                            TextField("0", value: Binding(get: { store.weekdayGoals[i] }, set: { store.setWeekdayGoal(i, $0) }), format: .number)
                                .textFieldStyle(.roundedBorder).multilineTextAlignment(.center)
                        }
                    }
                }
            }
            Field(icon: "paintpalette.fill", tint: .pink) {
                Text("Design")
                Spacer()
                Picker("Design", selection: store.$themeName) {
                    ForEach(Theme.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 170)
            }
            Field(icon: "menubar.rectangle", tint: .indigo) {
                Text("Icon")
                Spacer()
                ForEach(Store.menuIcons, id: \.self) { name in
                    Button { store.menuIcon = name } label: {
                        Image(systemName: name)
                            .frame(width: 24, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(store.menuIcon == name ? theme.border : Color.clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            Field(icon: "fork.knife", tint: .yellow) {
                Text("Mittagspause").lineLimit(1).fixedSize()
                Spacer()
                DatePicker("", selection: timeBinding(store.$lunchStart), displayedComponents: .hourAndMinute).labelsHidden()
                Text("–")
                DatePicker("", selection: timeBinding(store.$lunchEnd), displayedComponents: .hourAndMinute).labelsHidden()
            }
            Field(icon: "clock.badge", tint: .teal) {
                Text("Menüleiste").lineLimit(1).fixedSize()
                Spacer()
                Picker("Menüleiste", selection: Binding(get: { store.menuDisplay }, set: { store.menuDisplay = $0 })) {
                    ForEach(Store.MenuDisplay.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().frame(width: 170)
            }
            Field(icon: "power", tint: .red) {
                Text("Beim Login starten").lineLimit(1)
                Spacer()
                Toggle("", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) })).toggleStyle(.switch).labelsHidden()
            }
            Button { dismiss(); Task { await store.refresh(); await store.loadProjects() } } label: { Label("Speichern & neu laden", systemImage: "checkmark.circle.fill") }
                .buttonStyle(FilledButtonStyle(theme: theme, color: .blue))
        }
        .padding(20)
        .frame(width: 380)
        .themed(theme)
    }
}

struct MenuLabel: View {
    @EnvironmentObject var store: Store
    let text: String?
    let placeholder: String
    var body: some View {
        HStack {
            Text(text ?? placeholder)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(text == nil ? store.theme.secondaryText : store.theme.text)
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(store.theme.secondaryText)
        }
        .contentShape(Rectangle())
    }
}

struct Field<Content: View>: View {
    @EnvironmentObject var store: Store
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content
    var body: some View {
        let t = store.theme
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(t.tint(tint)).frame(width: 16)
            content.foregroundStyle(t.text)
        }
        .frame(height: 34)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.fieldFill))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(t.isColorful ? tint.opacity(0.6) : t.border))
    }
}

struct FilledButtonStyle: ButtonStyle {
    let theme: Theme
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        let fill: AnyShapeStyle = theme.isColorful
            ? AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(color)
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct Card<Content: View>: View {
    @EnvironmentObject var store: Store
    @ViewBuilder let content: Content
    var body: some View {
        let t = store.theme
        content
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(t.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(t.border))
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    private let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint]

    private func color(for a: Activity) -> Color {
        store.theme.tint(palette[abs(a.project?.id ?? a.id) % palette.count])
    }

    var body: some View {
        let theme = store.theme
        VStack(alignment: .leading, spacing: 12) {
            header
            summary
            inputs
            buttons

            if let e = store.error {
                Text(e)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.7)))
            }

            if !store.activities.isEmpty { activityList }

            Button("Beenden") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(14)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .themed(theme)
    }

    private var header: some View {
        let t = store.theme
        return HStack(spacing: 8) {
            Image(systemName: store.isCheckedIn ? "clock.badge.checkmark.fill" : "clock.fill")
                .font(.title2)
                .foregroundStyle(store.isCheckedIn ? .green : t.tint(.blue))
            Text("Moco").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(t.text)
            Spacer()
            if store.loading { ProgressView().controlSize(.small) }
            Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText)
            Button { openWindow(id: "history"); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "calendar") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText).help("Gebuchte Zeiten ansehen")
            Button { openWindow(id: "reconcile"); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "checklist") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText).help("Mit Excel abgleichen")
            Button { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "gearshape") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText)
        }
    }

    private var summary: some View {
        let t = store.theme
        let goal = store.goalToday
        let progress = min(1, store.bookedHours / max(goal, 0.1))
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Store.format(hours: store.bookedHours))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                Text("heute gebucht").font(.caption).opacity(0.8)
            }
            ProgressView(value: progress).tint(t.isColorful ? .white : (store.isCheckedIn ? .green : t.accent))
            HStack {
                Text("\(Int(progress * 100)) % von \(goal.formatted()) h")
                Spacer()
                if let reached = store.goalReachedAt {
                    Label("\(goal.formatted()) h erreicht um \(reached.formatted(date: .omitted, time: .shortened))", systemImage: "flag.checkered")
                } else if store.bookedHours >= goal {
                    Label("Überstunden +\(Store.format(hours: store.bookedHours - goal))", systemImage: "flag.checkered")
                }
            }
            .font(.caption2).opacity(0.8)
            if store.goalReachedAt != nil && store.pendingLunchMinutes > 0 {
                Label("inkl. \(store.pendingLunchMinutes) min Mittagspause", systemImage: "fork.knife")
                    .font(.caption2).opacity(0.8)
            }
        }
        .foregroundStyle(t.summaryText)
        .padding(14)
        .background(
            Group {
                if t.isColorful {
                    shape.fill(LinearGradient(colors: store.isCheckedIn ? [.green, .teal] : [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(t.cardFill)
                }
            }
        )
        .overlay(shape.stroke(t.isColorful ? Color.clear : t.border))
    }

    @ViewBuilder private var inputs: some View {
        if !store.projects.isEmpty {
            VStack(spacing: 8) {
                Field(icon: "folder.fill", tint: .purple) {
                    Menu {
                        ForEach(store.projects) { p in
                            Button(p.name) {
                                store.projectId = p.id
                                store.taskId = p.tasks.count == 1 ? p.tasks[0].id : 0
                            }
                        }
                    } label: {
                        MenuLabel(text: store.selectedProject?.name, placeholder: "Projekt wählen")
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                }
                Field(icon: "checklist", tint: .orange) {
                    Menu {
                        ForEach(store.selectedProject?.tasks ?? []) { t in
                            Button(t.name) { store.taskId = t.id }
                        }
                    } label: {
                        MenuLabel(text: store.selectedProject?.tasks.first { $0.id == store.taskId }?.name, placeholder: "Aufgabe wählen")
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                }
                HStack(spacing: 8) {
                    Field(icon: "timer", tint: .blue) {
                        TextField("2h", text: $store.duration).textFieldStyle(.plain)
                    }
                    .frame(width: 96)
                    Field(icon: "text.alignleft", tint: .teal) {
                        TextField("Notiz", text: $store.note).textFieldStyle(.plain)
                    }
                }
            }
        }
    }

    private var buttons: some View {
        let t = store.theme
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { Task { await store.checkIn() } } label: { Label("Start", systemImage: "play.fill") }
                    .buttonStyle(FilledButtonStyle(theme: t, color: .green))
                    .disabled(store.isCheckedIn || store.loading)
                Button { Task { await store.checkOut() } } label: { Label("Stopp", systemImage: "stop.fill") }
                    .buttonStyle(FilledButtonStyle(theme: t, color: .red))
                    .disabled(!store.isCheckedIn || store.loading)
            }
            Button { Task { await store.book() } } label: { Label("Dauer buchen", systemImage: "plus.circle.fill") }
                .buttonStyle(FilledButtonStyle(theme: t, color: t.isColorful ? .blue : t.accent))
                .disabled(store.duration.isEmpty || store.loading)
        }
    }

    private var activityList: some View {
        let t = store.theme
        return Card {
            VStack(spacing: 10) {
                ForEach(store.activities) { a in
                    let running = store.running?.id == a.id
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(color(for: a)).frame(width: 4, height: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.project?.name ?? "–").font(.callout.weight(.semibold)).lineLimit(1).foregroundStyle(t.text)
                            Text([a.task?.name, a.description].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(t.secondaryText).lineLimit(1)
                        }
                        Spacer()
                        Text(Store.format(hours: a.hours + (running ? store.runningSeconds(a) / 3600 : 0)))
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(running ? Color.white : t.text)
                            .padding(.horizontal, running ? 8 : 0).padding(.vertical, running ? 3 : 0)
                            .background(Capsule().fill(running ? Color.green : Color.clear))
                    }
                }
            }
        }
    }
}
