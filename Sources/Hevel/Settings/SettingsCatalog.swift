import SwiftUI

/// The panes in the settings sidebar.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, island, language

    var id: Self { self }

    /// The English name; also the key for the translations.
    var englishTitle: String {
        switch self {
        case .general: "General"
        case .island: "Island"
        case .language: "Language"
        }
    }

    var title: String { tr(englishTitle) }

    var icon: SettingsIcon {
        switch self {
        case .general: SettingsIcon(symbol: "gearshape.fill", color: .gray)
        case .island: SettingsIcon(symbol: "capsule.fill", color: .black)
        case .language: SettingsIcon(symbol: "globe", color: .blue)
        }
    }
}

/// Every setting the window shows, with the words the sidebar search finds it by.
/// The rows take their title and icon from here, so search and window can't drift apart.
enum SettingsItem: CaseIterable {
    case about, checkForUpdates, autoCheckForUpdates, installUpdatesAutomatically, skipSmallUpdates, updateFrequency
    case updateTimeOfDay
    case language, launchAtLogin
    case hideWhilePlayerInFront, showInFullscreen, flipArtwork, chargingAnimation, lockScreenIcon

    var pane: SettingsPane {
        switch self {
        case .about, .checkForUpdates, .autoCheckForUpdates, .installUpdatesAutomatically, .skipSmallUpdates, .updateFrequency,
             .updateTimeOfDay, .launchAtLogin:
            .general
        case .language:
            .language
        case .hideWhilePlayerInFront, .showInFullscreen, .flipArtwork, .chargingAnimation, .lockScreenIcon:
            .island
        }
    }

    var title: String { tr(englishTitle) }

    /// The English title; also the key for the translations.
    var englishTitle: String {
        switch self {
        case .about: "About"
        case .checkForUpdates: "Software Update"
        case .autoCheckForUpdates: "Check for updates automatically"
        case .installUpdatesAutomatically: "Install updates automatically"
        case .skipSmallUpdates: "Skip small updates"
        case .updateFrequency: "How often"
        case .updateTimeOfDay: "Time of day"
        case .language: "Language"
        case .launchAtLogin: "Launch at login"
        case .hideWhilePlayerInFront: "Hide while the playing app is in front"
        case .showInFullscreen: "Show in fullscreen apps"
        case .flipArtwork: "Flip the album art on track change"
        case .chargingAnimation: "Show the charging animation"
        case .lockScreenIcon: "Show a lock icon on the lock screen"
        }
    }

    var keywords: [String] {
        switch self {
        case .about: ["version", "info", "release notes", "github"]
        case .checkForUpdates: ["update", "check now", "new version", "latest", "last checked"]
        case .autoCheckForUpdates: ["update", "automatic", "background"]
        case .installUpdatesAutomatically: ["update", "install", "silent", "automatic", "background", "restart"]
        case .skipSmallUpdates: ["update", "skip", "small", "minor", "patch", "bugfix"]
        case .updateFrequency: ["update", "frequency", "schedule", "interval", "hourly", "daily", "weekly", "every"]
        case .updateTimeOfDay: ["update", "schedule", "morning", "afternoon", "evening", "time"]
        case .language: ["language", "translation", "english", "norwegian", "norsk", "hebrew", "עברית", "språk", "שפה"]
        case .launchAtLogin: ["login items", "startup", "start", "boot", "open"]
        case .hideWhilePlayerInFront: ["hide", "player", "spotify", "music", "front", "focus", "app"]
        case .showInFullscreen: ["fullscreen", "full screen", "hide", "video", "game"]
        case .flipArtwork: ["flip", "album", "artwork", "cover", "track", "song", "animation", "next", "previous"]
        case .chargingAnimation: ["charging", "battery", "power", "ring", "plug", "animation"]
        case .lockScreenIcon: ["lock", "lock screen", "locked", "login"]
        }
    }

    var symbol: String {
        switch self {
        case .about: "info"
        case .checkForUpdates: "arrow.down.circle.fill"
        case .autoCheckForUpdates: "arrow.triangle.2.circlepath"
        case .installUpdatesAutomatically: "arrow.down.app.fill"
        case .skipSmallUpdates: "forward.fill"
        case .updateFrequency: "calendar"
        case .updateTimeOfDay: "clock.fill"
        case .language: "globe"
        case .launchAtLogin: "power"
        case .hideWhilePlayerInFront: "macwindow"
        case .showInFullscreen: "arrow.up.left.and.arrow.down.right"
        case .flipArtwork: "music.note"
        case .chargingAnimation: "bolt.fill"
        case .lockScreenIcon: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .about, .autoCheckForUpdates, .launchAtLogin: .gray
        case .checkForUpdates, .language: .blue
        case .installUpdatesAutomatically: .purple
        case .skipSmallUpdates: .teal
        case .updateFrequency: .red
        case .updateTimeOfDay: .orange
        case .hideWhilePlayerInFront: .blue
        case .showInFullscreen: .teal
        case .flipArtwork: .pink
        case .chargingAnimation: .green
        case .lockScreenIcon: .indigo
        }
    }

    /// The settings a search shows: all of them for an empty query, otherwise those
    /// where every word of the query appears in the title, a keyword or the pane name
    /// (so "general" lists the whole General pane) — in English or the chosen language.
    static func matching(_ query: String) -> [SettingsItem] {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return allCases }
        return allCases.filter { item in
            let names = [item.title, item.englishTitle, item.pane.title, item.pane.englishTitle]
            let haystack = (names + item.keywords).joined(separator: " ")
            return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// The sidebar panes that have at least one match, in sidebar order.
    static func panes(matching query: String) -> [SettingsPane] {
        let panes = Set(matching(query).map(\.pane))
        return SettingsPane.allCases.filter(panes.contains)
    }
}

/// A row label with the item's colored icon.
struct SettingsLabel: View {
    let item: SettingsItem
    var subtitle: String?

    init(_ item: SettingsItem, subtitle: String? = nil) {
        self.item = item
        self.subtitle = subtitle
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            SettingsIcon(symbol: item.symbol, color: item.color)
        }
    }
}
