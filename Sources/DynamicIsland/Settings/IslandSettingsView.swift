import SwiftUI

/// When the island shows and how it animates.
struct IslandSettingsView: View {
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>

    @AppStorage(Preferences.hideWhilePlayerInFrontKey) private var hideWhilePlayerInFront = true
    @AppStorage(Preferences.showInFullscreenKey) private var showInFullscreen = false
    @AppStorage(Preferences.flipArtworkKey) private var flipArtwork = true
    @AppStorage(Preferences.chargingAnimationKey) private var chargingAnimation = true
    @AppStorage(Preferences.lockScreenIconKey) private var lockScreenIcon = true

    var body: some View {
        Form {
            section("Visibility", [
                (.hideWhilePlayerInFront, $hideWhilePlayerInFront),
                (.showInFullscreen, $showInFullscreen),
            ])
            section("Animations", [
                (.flipArtwork, $flipArtwork),
                (.chargingAnimation, $chargingAnimation),
            ])
            section("Lock Screen", [
                (.lockScreenIcon, $lockScreenIcon),
            ])
        }
        .formStyle(.grouped)
    }

    /// A section of toggles, left out entirely when the search hides all of them.
    @ViewBuilder
    private func section(_ title: String, _ toggles: [(SettingsItem, Binding<Bool>)]) -> some View {
        let visible = toggles.filter { shown.contains($0.0) }
        if !visible.isEmpty {
            Section(title) {
                ForEach(visible, id: \.0) { item, isOn in
                    Toggle(isOn: isOn) {
                        SettingsLabel(item)
                    }
                }
            }
        }
    }
}
