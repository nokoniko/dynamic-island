import SwiftUI

/// General → Software Update: checking now and how updates are checked and installed.
struct UpdateSettingsView: View {
    @ObservedObject var updater: Updater
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>

    @AppStorage(Preferences.autoCheckForUpdatesKey) private var autoCheckForUpdates = true
    @AppStorage(Preferences.installUpdatesAutomaticallyKey) private var installUpdatesAutomatically = true
    @AppStorage(Preferences.skipSmallUpdatesKey) private var skipSmallUpdates = false
    @AppStorage(Preferences.updateFrequencyKey) private var updateFrequency = UpdateFrequency.daily
    @AppStorage(Preferences.updateTimeOfDayKey) private var updateTimeOfDay = UpdateTimeOfDay.morning
    @AppStorage(Preferences.lastUpdateCheckKey) private var lastUpdateCheck = 0.0

    private static let automatic: [SettingsItem] = [.autoCheckForUpdates, .installUpdatesAutomatically,
                                                    .skipSmallUpdates, .updateFrequency, .updateTimeOfDay]

    var body: some View {
        if shown.contains(.checkForUpdates) {
            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        if updater.isChecking {
                            ProgressView().controlSize(.small)
                        }
                        Button(tr("Check Now")) { updater.check(userInitiated: true) }
                            .disabled(updater.isChecking)
                    }
                } label: {
                    SettingsLabel(.checkForUpdates, subtitle: updateStatus)
                }
            }
        }
        if Self.automatic.contains(where: shown.contains) {
            Section {
                if shown.contains(.autoCheckForUpdates) {
                    Toggle(isOn: $autoCheckForUpdates) {
                        SettingsLabel(.autoCheckForUpdates)
                    }
                }
                if shown.contains(.installUpdatesAutomatically) {
                    Toggle(isOn: $installUpdatesAutomatically) {
                        SettingsLabel(.installUpdatesAutomatically,
                                      subtitle: tr("Without asking — the app restarts when nothing is playing"))
                    }
                    .disabled(!autoCheckForUpdates)
                }
                if shown.contains(.skipSmallUpdates) {
                    Toggle(isOn: $skipSmallUpdates) {
                        SettingsLabel(.skipSmallUpdates,
                                      subtitle: tr("Only updates like 2.3, not 2.2.7 — Check Now still shows every update"))
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
                            Text(verbatim: "\(time.title) (\(hourText(time.hour)))").tag(time)
                        }
                    } label: {
                        SettingsLabel(.updateTimeOfDay,
                                      subtitle: updateFrequency == .hourly ? tr("Not used when checking every hour") : nil)
                    }
                    .disabled(!autoCheckForUpdates || updateFrequency == .hourly)
                }
            }
        }
    }

    /// "Last checked …" plus when the next automatic check runs.
    private var updateStatus: String {
        guard updater.isEnabled else { return tr("Updates aren't available in this build") }
        let last = lastUpdateCheck > 0
            ? tr("Last checked: %@", relative(Date(timeIntervalSince1970: lastUpdateCheck)))
            : tr("Not checked yet")
        guard autoCheckForUpdates else { return last }
        let next = max(Preferences.nextUpdateCheck(), Date())
        return "\(last) · \(tr("Next: %@", relative(next)))"
    }

    /// "Today at 09:00", in the chosen language.
    private func relative(_ date: Date) -> String {
        let calendar = Calendar.current
        let locale = Localization.locale
        let day = if calendar.isDateInToday(date) { tr("Today") }
            else if calendar.isDateInTomorrow(date) { tr("Tomorrow") }
            else if calendar.isDateInYesterday(date) { tr("Yesterday") }
            else { date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(locale)) }
        return tr("%1$@ at %2$@", day, date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale)))
    }

    private func hourText(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localization.locale))
    }
}
