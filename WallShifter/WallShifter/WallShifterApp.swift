import SwiftUI

@main
struct WallShifterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window scenes — this is a menu bar agent (LSUIElement = YES).
        // The preferences window is opened manually by AppDelegate.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    let configStore = ConfigStore()

    private var systemWallpaperStore: SystemWallpaperStore?
    private var displayManager: DisplayManager?
    private var sourceManager: SourceManager?
    private var wallpaperEngine: WallpaperEngine?
    private var menuBarManager: MenuBarManager?
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Snapshot system wallpapers before we touch anything
        let wallpaperStore = SystemWallpaperStore()
        systemWallpaperStore = wallpaperStore

        // 2. Build the dependency graph
        let displays = DisplayManager(configStore: configStore)
        displayManager = displays

        let sources = SourceManager(configStore: configStore)
        sourceManager = sources

        let engine = WallpaperEngine(
            sourceManager: sources,
            displayManager: displays,
            configStore: configStore
        )
        wallpaperEngine = engine

        // 3. Menu bar (needs wallpaperStore for quit handler)
        let bar = MenuBarManager(systemWallpaperStore: wallpaperStore)
        menuBarManager = bar

        // 4. Wire callbacks between engine and menu bar
        engine.menuBarManager = bar
        bar.onNext = { [weak engine] in engine?.next() }
        bar.onPauseToggle = { [weak engine] in
            guard let engine else { return }
            engine.isPaused.toggle()
        }
        bar.onPreferences = { [weak self] in self?.openPreferences() }

        // 5. Kick off rotation
        let changeOnLaunch = configStore.config.schedule.changeOnLaunch
        engine.start(changeOnLaunch: changeOnLaunch)

        // 6. Always register for wake-from-sleep; the handler checks the live setting.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        systemWallpaperStore?.restore()
    }

    // MARK: - Preferences window

    private func openPreferences() {
        if preferencesWindow == nil {
            let view = PreferencesView().environmentObject(configStore)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "WallShifter Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 520, height: 480))
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Wake notification

    @objc private func handleWake() {
        guard configStore.config.schedule.changeOnWake else { return }
        wallpaperEngine?.next()
    }
}
