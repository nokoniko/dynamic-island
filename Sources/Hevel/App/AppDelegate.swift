import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = NowPlayingModel()
    private let updater = Updater()
    private lazy var settings = SettingsWindowController(updater: updater)
    private var controller: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activation policy (.accessory — agent app, no Dock icon) is set in main.swift
        // before the app launches.
        Preferences.register()
        controller = NotchController(model: model)
        model.start()
        updater.canRestartQuietly = { [unowned self] in
            !model.isPlaying && !settings.isOpen && !Self.screenIsLocked
        }
        updater.start()
        setupStatusItem()
        setupMainMenu()
    }

    private static var screenIsLocked: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "capsule.fill",
                                   accessibilityDescription: "Hevel")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Hevel \(updater.currentVersion)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

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

    /// Only visible while the settings window makes the app a regular app. There's
    /// deliberately no Hide — it would hide the island too.
    private func setupMainMenu() {
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Hevel", action: #selector(confirmQuit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func openSettings() { settings.show() }

    @objc private func confirmQuit() { settings.confirmQuit { NSApp.terminate(nil) } }

    @objc private func checkForUpdates() { updater.check(userInitiated: true) }

    @objc private func quit() { NSApp.terminate(nil) }
}
