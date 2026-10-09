import SwiftUI

/// The Language pane.
struct LanguageSettingsView: View {
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>

    @AppStorage(Preferences.appLanguageKey) private var language = AppLanguage.system

    var body: some View {
        if shown.contains(.language) {
            Section {
                Picker(selection: $language) {
                    ForEach(AppLanguage.allCases) { Text(verbatim: $0.name).tag($0) }
                } label: {
                    SettingsLabel(.language)
                }
            }
        }
    }
}
