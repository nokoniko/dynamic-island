import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = NowPlayingModel()
    private let updater = Updater()
    private var controller: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activation policy (.accessory — agent app, no Dock icon) is set in main.swift
        // before the app launches.
        controller = NotchController(model: model)
        model.start()
        updater.start()
        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "capsule.fill",
                                   accessibilityDescription: "Dynamic Island")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Dynamic Island \(updater.currentVersion)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func checkForUpdates() { updater.check(userInitiated: true) }

    @objc private func quit() { NSApp.terminate(nil) }
}
