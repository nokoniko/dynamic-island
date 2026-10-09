import SwiftUI
import ServiceManagement

/// About, Software Update and Startup.
struct GeneralSettingsView: View {
    @ObservedObject var updater: Updater
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>

    @AppStorage(Preferences.autoCheckForUpdatesKey) private var autoCheckForUpdates = true
    @AppStorage(Preferences.installUpdatesAutomaticallyKey) private var installUpdatesAutomatically = true
    @AppStorage(Preferences.updateFrequencyKey) private var updateFrequency = UpdateFrequency.daily
    @AppStorage(Preferences.updateTimeOfDayKey) private var updateTimeOfDay = UpdateTimeOfDay.morning
    @AppStorage(Preferences.lastUpdateCheckKey) private var lastUpdateCheck = 0.0

    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    var body: some View {
        Form {
            if shown.contains(.about) {
                Section {
                    about
                }
            }

            if shown.contains(where: { [.checkForUpdates, .autoCheckForUpdates, .installUpdatesAutomatically, .updateFrequency, .updateTimeOfDay].contains($0) }) {
                Section("Software Update") {
                    if shown.contains(.checkForUpdates) {
                        LabeledContent {
                            HStack(spacing: 8) {
                                if updater.isChecking {
                                    ProgressView().controlSize(.small)
                                }
                                Button("Check Now") { updater.check(userInitiated: true) }
                                    .disabled(updater.isChecking)
                            }
                        } label: {
                            SettingsLabel(.checkForUpdates, subtitle: updateStatus)
                        }
                    }
                    if shown.contains(.autoCheckForUpdates) {
                        Toggle(isOn: $autoCheckForUpdates) {
                            SettingsLabel(.autoCheckForUpdates)
                        }
                    }
                    if shown.contains(.installUpdatesAutomatically) {
                        Toggle(isOn: $installUpdatesAutomatically) {
                            SettingsLabel(.installUpdatesAutomatically,
                                          subtitle: "Without asking — the app restarts when nothing is playing")
                        }
                        .disabled(!autoCheckForUpdates)
                    }
                    if shown.contains(.updateFrequency) {
                        Picker(selection: $updateFrequency) {
                            ForEach(UpdateFrequency.allCases) { Text($0.title).tag($0) }
                        } label: {
                            SettingsLabel(.updateFrequency)
                        }
                        .disabled(!autoCheckForUpdates)
                    }
                    if shown.contains(.updateTimeOfDay) {
                        Picker(selection: $updateTimeOfDay) {
                            ForEach(UpdateTimeOfDay.allCases) { time in
                                Text("\(time.title) (\(hourText(time.hour)))").tag(time)
                            }
                        } label: {
                            SettingsLabel(.updateTimeOfDay,
                                          subtitle: updateFrequency == .hourly ? "Not used when checking every hour" : nil)
                        }
                        .disabled(!autoCheckForUpdates || updateFrequency == .hourly)
                    }
                }
            }

            if shown.contains(.launchAtLogin) {
                Section("Startup") {
                    Toggle(isOn: launchAtLogin) {
                        SettingsLabel(.launchAtLogin)
                    }
                    if loginStatus == .requiresApproval {
                        LabeledContent("Allow Dynamic Island in Login Items.") {
                            Button("Open Settings") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        .foregroundStyle(.secondary)
                    }
                    if let loginError {
                        Text(loginError)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    private var about: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("Dynamic Island")
                    .font(.title3.weight(.semibold))
                Text("Version \(updater.currentVersion)")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if let repo = updater.repo, let url = URL(string: "https://github.com/\(repo)/releases") {
                Link("Release Notes", destination: url)
            }
        }
        .padding(.vertical, 4)
    }

    /// "Last checked …" plus when the next automatic check runs.
    private var updateStatus: String {
        guard updater.isEnabled else { return "Updates aren't available in this build" }
        let last = lastUpdateCheck > 0
            ? "Last checked: \(relative(Date(timeIntervalSince1970: lastUpdateCheck)))"
            : "Not checked yet"
        guard autoCheckForUpdates else { return last }
        let next = max(Preferences.nextUpdateCheck(), Date())
        return "\(last) · Next: \(relative(next))"
    }

    /// "Today at 09:00", in English like the rest of the window.
    private func relative(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = if calendar.isDateInToday(date) { "Today" }
            else if calendar.isDateInTomorrow(date) { "Tomorrow" }
            else if calendar.isDateInYesterday(date) { "Yesterday" }
            else { date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "en"))) }
        return "\(day) at \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { loginStatus == .enabled || loginStatus == .requiresApproval },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    loginError = nil
                } catch {
                    loginError = error.localizedDescription
                }
                loginStatus = SMAppService.mainApp.status
            }
        )
    }
}

