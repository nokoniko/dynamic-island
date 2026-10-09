import AppKit

/// Checks GitHub Releases for a newer signed build and offers to install it.
///
/// Configuration comes from Info.plist, written by `builder`: `DIUpdateRepo`
/// ("owner/repo") and `DIUpdatePublicKey` (hex Ed25519 key). Without both — or
/// when not running from a `.app` bundle (e.g. `swift run`) — the updater is off.
@MainActor
final class Updater: ObservableObject {
    let repo: String?
    private let publicKey: String?
    private var timer: Timer?
    /// After a background check fails (offline, GitHub down), don't retry before this.
    private var retryAfter: Date?
    @Published private(set) var isChecking = false
    private let skippedVersionKey = "DIUpdaterSkippedVersion"

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Whether this build can update itself at all.
    var isEnabled: Bool {
        repo != nil && publicKey != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        repo = (info["DIUpdateRepo"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        publicKey = (info["DIUpdatePublicKey"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Looks a little after launch (so startup stays light), then every few minutes,
    /// whether the schedule from the settings says a check is due. Polling instead of
    /// one long timer keeps it right across sleep and changed settings.
    func start() {
        guard isEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkIfDue() }
        let timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
        timer.tolerance = 60
        self.timer = timer
    }

    private func checkIfDue() {
        let now = Date()
        guard Preferences.autoCheckForUpdates,
              retryAfter.map({ now >= $0 }) ?? true,
              now >= Preferences.nextUpdateCheck(now: now)
        else { return }
        check(userInitiated: false)
    }

    /// Look for a newer release. A check from the menu always reports back; the
    /// background check only speaks up when there's an update the user hasn't skipped.
    func check(userInitiated: Bool) {
        guard isEnabled, let repo, let publicKey else {
            if userInitiated { inform("Automatic updates aren't enabled in this build.") }
            return
        }
        guard !isChecking else { return }
        isChecking = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isChecking = false }
            var installing = false
            do {
                let latest = try await ReleaseFeed.latest(repo: repo)
                Preferences.lastUpdateCheck = Date()
                self.retryAfter = nil
                guard let release = latest,
                      ReleaseFeed.isVersion(release.version, newerThan: self.currentVersion)
                else {
                    if userInitiated { self.inform("You're on the latest version (\(self.currentVersion)).") }
                    return
                }
                if !userInitiated,
                   UserDefaults.standard.string(forKey: self.skippedVersionKey) == release.version {
                    return
                }
                guard self.askToInstall(release) else { return }

                installing = true
                let prepared = try await UpdateInstaller.prepare(release, publicKeyHex: publicKey)
                try UpdateInstaller.installAndRelaunch(newApp: prepared.app, workDir: prepared.workDir)
            } catch {
                // Quiet about background network hiccups; loud once the user is involved.
                if userInitiated || installing {
                    self.inform("The update failed: \(error.localizedDescription)")
                } else {
                    self.retryAfter = Date().addingTimeInterval(30 * 60)
                }
            }
        }
    }

    /// Returns true if the user wants to install now.
    private func askToInstall(_ release: ReleaseInfo) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Dynamic Island \(release.version) is available"
        alert.informativeText = "You have \(currentVersion). Update now? The app will restart."
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return true
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(release.version, forKey: skippedVersionKey)
            return false
        default:
            return false
        }
    }

    private func inform(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Dynamic Island"
        alert.informativeText = text
        NSApp.activate()
        alert.runModal()
    }
}
