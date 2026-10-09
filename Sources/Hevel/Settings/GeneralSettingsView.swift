import SwiftUI
import ServiceManagement

/// The General pane: About, a link to Software Update, and Startup.
struct GeneralSettingsView: View {
    @ObservedObject var updater: Updater
    /// The rows the sidebar search leaves visible.
    let shown: Set<SettingsItem>
    /// While searching, the matching update rows show here instead of behind the link.
    let searching: Bool
    let openSoftwareUpdate: () -> Void

    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    var body: some View {
        Group {
            if shown.contains(.about) {
                Section {
                    about
                }
            }

            if searching {
                UpdateSettingsView(updater: updater, shown: shown)
            } else {
                Section {
                    Button(action: openSoftwareUpdate) {
                        HStack {
                            SettingsLabel(.checkForUpdates)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if shown.contains(.launchAtLogin) {
                Section(tr("Startup")) {
                    Toggle(isOn: launchAtLogin) {
                        SettingsLabel(.launchAtLogin)
                    }
                    if loginStatus == .requiresApproval {
                        LabeledContent(tr("Allow Hevel in Login Items.")) {
                            Button(tr("Open Settings")) { SMAppService.openSystemSettingsLoginItems() }
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
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    private var about: some View {
        HStack(spacing: 14) {
            // The icon's artwork without the Dock backdrop, written by the builder.
            if let artwork = Bundle.main.image(forResource: "IconArtwork") {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 56)
            } else {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "Hevel")
                    .font(.title3.weight(.semibold))
                Text(tr("Version %@", updater.currentVersion))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if let repo = updater.repo, let url = URL(string: "https://github.com/\(repo)/releases") {
                Link(tr("Release Notes"), destination: url)
            }
        }
        .padding(.vertical, 4)
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
