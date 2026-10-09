import AppKit

extension NotchController {

    func setupActivation() {
        state.onTapIsland = { [weak self] in self?.activatePlayingApp() }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }

        // Re-evaluate when what's playing changes.
        model.$playingPID.removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }
            .store(in: &cancellables)
        model.$isPlaying.removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }
            .store(in: &cancellables)
        model.$hasMedia.removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }
            .store(in: &cancellables)

        // Apply the "hide while the playing app is in front" setting as soon as it changes.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.updateSuppressed() } }

        updateSuppressed()
    }

    private func updateSuppressed() {
        state.suppressedForFrontmost = Preferences.hideWhilePlayerInFront && isPlayerFrontmost()
        updateForPointer()
    }

    /// True when the app that owns the current track is already the frontmost app —
    /// then there's no point showing the island (including during the pause linger).
    private func isPlayerFrontmost() -> Bool {
        Self.isPlayerFrontmost(
            hasMedia: model.hasMedia,
            playingPID: model.playingPID,
            frontmost: {
                NSWorkspace.shared.frontmostApplication.map {
                    (pid: Int($0.processIdentifier), bundleID: $0.bundleIdentifier)
                }
            },
            bundleID: { NSRunningApplication(processIdentifier: pid_t($0))?.bundleIdentifier }
        )
    }

    /// The system lookups are closures so they only run when needed, as before.
    nonisolated static func isPlayerFrontmost(hasMedia: Bool, playingPID: Int?,
                                              frontmost: () -> (pid: Int, bundleID: String?)?,
                                              bundleID: (Int) -> String?) -> Bool {
        guard hasMedia, let pid = playingPID, let front = frontmost() else { return false }
        if front.pid == pid { return true }
        // Browsers register now-playing from a helper process — match the app family.
        if let pb = bundleID(pid), let fb = front.bundleID {
            return pb == fb || pb.hasPrefix(fb) || fb.hasPrefix(pb)
        }
        return false
    }

    private func activatePlayingApp() {
        guard let pid = model.playingPID,
              let app = NSRunningApplication(processIdentifier: pid_t(pid)) else { return }
        app.activate(options: [.activateAllWindows])
    }
}
