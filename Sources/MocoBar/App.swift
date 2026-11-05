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
                if store.menuShowTime, let r = store.running {
                    Text(Store.format(hours: store.runningSeconds(r) / 3600))
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Moco-Einstellungen", id: "settings") {
            SettingsView().environmentObject(store)
        }
        .windowResizability(.contentSize)

        Window("Zeitabgleich", id: "reconcile") {
            ReconcileView().environmentObject(store)
        }
        .defaultSize(width: 560, height: 520)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
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
            Field(icon: "clock.badge", tint: .teal) {
                Toggle("Laufende Zeit in der Menüleiste", isOn: store.$menuShowTime).toggleStyle(.switch)
                Spacer()
            }
            Button { dismiss(); Task { await store.refresh(); await store.loadProjects() } } label: { Label("Speichern & neu laden", systemImage: "checkmark.circle.fill") }
                .buttonStyle(FilledButtonStyle(theme: theme, color: .blue))
        }
        .padding(20)
        .frame(width: 340)
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
            Button { openWindow(id: "reconcile"); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "checklist") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText).help("Mit Excel abgleichen")
            Button { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "gearshape") }.buttonStyle(.borderless).foregroundStyle(t.secondaryText)
        }
    }

    private var summary: some View {
        let t = store.theme
        let progress = min(1, store.bookedHours / max(store.dailyGoal, 0.1))
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Store.format(hours: store.bookedHours))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                Text("heute gebucht").font(.caption).opacity(0.8)
            }
            ProgressView(value: progress).tint(t.isColorful ? .white : (store.isCheckedIn ? .green : t.accent))
            Text("\(Int(progress * 100)) % von \(store.dailyGoal.formatted()) h").font(.caption2).opacity(0.8)
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
