import AppKit
import SwiftUI

/// Owns the single settings window and brings it to the front on request. While
/// it's open the app shows in the Dock and the app switcher like a regular app.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let updater: Updater
    private var window: NSWindow?
    /// The selected pane's name; SwiftUI reports it before the window exists.
    private var title = SettingsPane.general.title {
        didSet { window?.title = title }
    }

    var isOpen: Bool { window?.isVisible == true }

    init(updater: Updater) {
        self.updater = updater
    }

    func show() {
        if window == nil {
            let view = SettingsView(updater: updater) { [weak self] title in
                self?.title = title
            }
            let hosting = NSHostingController(rootView: view)
            // Let SwiftUI drive the toolbar (sidebar layout), like System Settings.
            hosting.sceneBridgingOptions = [.toolbars]
            let window = NSWindow(contentViewController: hosting)
            window.title = title
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        guard let window else { return }
        let alreadyOpen = window.isVisible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        // Opened from the menu bar another app is still active, and macOS may not
        // hand activation over — so put the window in front regardless.
        window.orderFrontRegardless()
        // Centered after it's laid out (toolbar included), still within this run-loop
        // turn, so it never visibly jumps.
        if !alreadyOpen { center(window) }
    }

    /// Dead center of the screen the pointer is on, i.e. where the user is looking.
    private func center(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return window.center() }
        // SwiftUI sizes the window lazily; settle it first or we'd center a 0×0 frame.
        window.layoutIfNeeded()
        window.displayIfNeeded()
        let area = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: (area.midX - size.width / 2).rounded(),
                                      y: (area.midY - size.height / 2).rounded()))
    }

    /// ⌘Q from the settings window quits the whole app — island included — so ask
    /// first. Without the window open it quits straight away.
    func confirmQuit(then quit: @escaping () -> Void) {
        guard let window, window.isVisible else { return quit() }
        let alert = NSAlert()
        alert.messageText = "Quit Hevel?"
        alert.informativeText = "The island disappears from the notch until you open the app again. To just close the settings, press ⌘W."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { quit() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only agent: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
    }
}
