import SwiftUI

/// The settings window, laid out like System Settings: a search field and a sidebar
/// of panes with colored icons on the left, the selected pane on the right. Searching
/// narrows the sidebar to the panes with matches and the pane to the matching rows.
struct SettingsView: View {
    @ObservedObject var updater: Updater
    /// The window title follows the selected pane.
    let setTitle: (String) -> Void

    @State private var selection: SettingsPane? = .general
    @State private var query = ""

    private var matches: Set<SettingsItem> { Set(SettingsItem.matching(query)) }
    private var panes: [SettingsPane] { SettingsItem.panes(matching: query) }

    var body: some View {
        NavigationSplitView {
            List(panes, selection: $selection) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    pane.icon
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: "Search")
            // The column width alone is ignored outside a SwiftUI scene, so pin the list too.
            .frame(minWidth: 215)
            .navigationSplitViewColumnWidth(215)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if panes.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                switch selection ?? .general {
                case .general:
                    GeneralSettingsView(updater: updater, shown: matches)
                case .island:
                    IslandSettingsView(shown: matches)
                }
            }
        }
        .frame(width: 715, height: 470)
        .onChange(of: panes, initial: true) {
            // Keep the selection on a pane that still has matches.
            if let first = panes.first, !panes.contains(selection ?? .general) { selection = first }
        }
        .onChange(of: selection, initial: true) {
            setTitle((selection ?? .general).title)
        }
    }
}
