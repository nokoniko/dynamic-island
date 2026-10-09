import SwiftUI

/// Where the settings window is: a sidebar pane, or a page inside one.
enum SettingsPage: Hashable {
    case pane(SettingsPane)
    case softwareUpdate

    /// The sidebar pane that stays selected.
    var pane: SettingsPane {
        switch self {
        case .pane(let pane): pane
        case .softwareUpdate: .general
        }
    }
}

/// Back/forward history over the pages visited, like a browser's.
struct SettingsHistory {
    private(set) var current: SettingsPage = .pane(.general)
    private var back: [SettingsPage] = []
    private var forward: [SettingsPage] = []

    var canGoBack: Bool { !back.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }

    mutating func go(to page: SettingsPage) {
        guard page != current else { return }
        back.append(current)
        forward.removeAll()
        current = page
    }

    mutating func goBack() {
        guard let page = back.popLast() else { return }
        forward.append(current)
        current = page
    }

    mutating func goForward() {
        guard let page = forward.popLast() else { return }
        back.append(current)
        current = page
    }

    /// Moves without leaving a step behind (e.g. when search hides the current pane).
    mutating func replace(with page: SettingsPage) {
        current = page
    }
}

/// The settings window, laid out like System Settings: a search field and a sidebar
/// of panes with colored icons on the left, the selected pane on the right, and
/// back/forward arrows in the toolbar. Searching narrows the sidebar to the panes
/// with matches and the pane to the matching rows. There's no window title; the
/// sidebar shows where you are.
struct SettingsView: View {
    @ObservedObject var updater: Updater

    @State private var history = SettingsHistory()
    @State private var query = ""
    @AppStorage(Preferences.appLanguageKey) private var language = AppLanguage.system

    private var matches: Set<SettingsItem> { Set(SettingsItem.matching(query)) }
    private var panes: [SettingsPane] { SettingsItem.panes(matching: query) }

    private var selection: Binding<SettingsPane?> {
        Binding(get: { history.current.pane },
                set: { pane in if let pane { history.go(to: .pane(pane)) } })
    }

    var body: some View {
        NavigationSplitView {
            List(panes, selection: selection) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    pane.icon
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: tr("Search"))
            // The column width alone is ignored outside a SwiftUI scene, so pin the list too.
            .frame(minWidth: 215)
            .navigationSplitViewColumnWidth(215)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                if panes.isEmpty {
                    ContentUnavailableView(tr("No Results"), systemImage: "magnifyingglass",
                                           description: Text(tr("Check the spelling or try a new search.")))
                } else {
                    Form {
                        switch history.current {
                        case .pane(.general):
                            GeneralSettingsView(updater: updater, shown: matches, searching: !query.isEmpty) {
                                history.go(to: .softwareUpdate)
                            }
                        case .softwareUpdate:
                            UpdateSettingsView(updater: updater, shown: matches)
                        case .pane(.island):
                            IslandSettingsView(shown: matches)
                        case .pane(.language):
                            LanguageSettingsView(shown: matches)
                        }
                    }
                    .formStyle(.grouped)
                    // Open at the top (right-to-left otherwise starts at the end).
                    .defaultScrollAnchor(.top)
                    .id(history.current)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ControlGroup {
                        Button { history.goBack() } label: { Image(systemName: "chevron.backward") }
                            .disabled(!history.canGoBack)
                            .help(tr("Back"))
                            .keyboardShortcut("[", modifiers: .command)
                        Button { history.goForward() } label: { Image(systemName: "chevron.forward") }
                            .disabled(!history.canGoForward)
                            .help(tr("Forward"))
                            .keyboardShortcut("]", modifiers: .command)
                    }
                    .controlGroupStyle(.navigation)
                }
            }
        }
        // Rebuilt in the new language at once; Hebrew also mirrors the layout.
        .id(language)
        .environment(\.locale, Localization.locale)
        .environment(\.layoutDirection, Localization.isRightToLeft ? .rightToLeft : .leftToRight)
        .frame(width: 715, height: 470)
        .onChange(of: panes, initial: true) {
            // Keep the selection on a pane that still has matches.
            if let first = panes.first, !panes.contains(history.current.pane) {
                history.replace(with: .pane(first))
            }
        }
    }
}
