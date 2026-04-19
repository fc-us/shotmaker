import SwiftUI
import UserNotifications

extension Notification.Name {
    static let focusSearch = Notification.Name("org.frontiercommons.shot-maker.focusSearch")
    static let pasteAndSearch = Notification.Name("org.frontiercommons.shot-maker.pasteAndSearch")
}

@main
struct ShotMakerApp: App {
    @StateObject private var watcher: ScreenshotWatcher = ScreenshotWatcher.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @NSApplicationDelegateAdaptor(StatusBarDelegate.self) var statusBarDelegate

    var body: some Scene {
        WindowGroup("ShotMaker") {
            MainWindowView()
                .environmentObject(watcher)
                .environmentObject(appSettings)
                .frame(minWidth: 700, minHeight: 400)
        }
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
                .environmentObject(appSettings)
        }
    }
}

class StatusBarDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var watcher: ScreenshotWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item immediately on launch
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "basketball.fill", accessibilityDescription: "ShotMaker")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        // Wire the shared watcher immediately so the menu shows live counts before the window opens
        self.watcher = ScreenshotWatcher.shared
        rebuildMenu()

        // ⌥⌘F global hotkey: bring window forward + focus search
        HotkeyService.shared.register()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleHotkey),
            name: HotkeyService.hotkeyPressed, object: nil
        )

        NSApplication.shared.activate(ignoringOtherApps: true)

        // First launch: ask user to grant sandbox access to their screenshots folder
        if !AppSettings.shared.hasWatchDirectoryPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.requestDirectoryPermission()
            }
        }
    }

    private func requestDirectoryPermission() {
        let panel = NSOpenPanel()
        panel.message = "Choose the folder ShotMaker should watch for new screenshots.\n\nThis is usually your Desktop."
        panel.prompt = "Watch This Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        try? AppSettings.shared.saveWatchDirectory(url)
        ScreenshotWatcher.shared.startWatching()
    }

    @objc func handleHotkey() {
        openApp()
        // Let the window come up, then ping the search field to take focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .focusSearch, object: nil)
        }
    }

    func setWatcher(_ watcher: ScreenshotWatcher) {
        self.watcher = watcher
        rebuildMenu()
    }

    func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let count = watcher?.totalCount ?? 0
        let watching = watcher?.isWatching ?? true

        let info = NSMenuItem(title: "\(count) screenshots · \(watching ? "Watching" : "Paused")", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open ShotMaker", action: #selector(openApp), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let toggleTitle = watching ? "Pause Watching" : "Resume Watching"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleWatching), keyEquivalent: "p")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let feedbackItem = NSMenuItem(title: "Send Feedback", action: #selector(sendFeedback), keyEquivalent: "")
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ShotMaker", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc func openApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.title == "ShotMaker" {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func toggleWatching() {
        watcher?.toggleWatching()
    }

    @objc func sendFeedback() {
        if let url = URL(string: "https://github.com/fc-us/shotmaker/issues/new?labels=feedback&template=feedback.md") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension StatusBarDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
