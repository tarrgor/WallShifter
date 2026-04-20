import AppKit

/// Owns the menu-bar `NSStatusItem` and drives all menu interactions.
///
/// After initialising, wire `nextChangeDate` and `isPaused` from `WallpaperEngine`
/// to get live countdowns and accurate pause/resume labelling.
final class MenuBarManager {

    // MARK: - External state (set by WallpaperEngine once it exists)

    /// The date at which the next automatic wallpaper change will occur.
    /// `nil` means no change is scheduled (e.g. engine is paused or not yet started).
    var nextChangeDate: Date? {
        didSet { refreshCountdownItem() }
    }

    /// Reflects the engine's pause state; keeps the menu item label in sync.
    var isPaused: Bool = false {
        didSet { pauseItem.title = isPaused ? "Resume" : "Pause" }
    }

    // MARK: - Callbacks (wired by AppDelegate / WallpaperEngine in a later step)

    var onNext: (() -> Void)?
    var onPauseToggle: (() -> Void)?
    var onPreferences: (() -> Void)?

    // MARK: - Private

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let countdownItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let systemWallpaperStore: SystemWallpaperStore
    private var countdownTimer: Timer?

    // MARK: - Init

    init(systemWallpaperStore: SystemWallpaperStore) {
        self.systemWallpaperStore = systemWallpaperStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton()
        buildMenu()
        startCountdownTimer()
    }

    deinit {
        countdownTimer?.invalidate()
    }

    // MARK: - Setup

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                            accessibilityDescription: "WallShifter")
        image?.isTemplate = true
        button.image = image
    }

    private func buildMenu() {
        // Countdown label — non-interactive, updated every second
        countdownItem.isEnabled = false
        refreshCountdownItem()
        menu.addItem(countdownItem)

        menu.addItem(.separator())

        // Next Wallpaper
        let nextItem = NSMenuItem(title: "Next Wallpaper",
                                  action: #selector(handleNext),
                                  keyEquivalent: "")
        nextItem.target = self
        menu.addItem(nextItem)

        menu.addItem(.separator())

        // Pause / Resume toggle
        pauseItem.title = "Pause"
        pauseItem.action = #selector(handlePauseToggle)
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences…",
                                   action: #selector(handlePreferences),
                                   keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit WallShifter",
                                  action: #selector(handleQuit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Countdown timer

    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshCountdownItem()
        }
    }

    private func refreshCountdownItem() {
        guard let target = nextChangeDate else {
            countdownItem.title = "Next change: —"
            return
        }
        let remaining = target.timeIntervalSinceNow
        guard remaining > 0 else {
            countdownItem.title = "Changing…"
            return
        }
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        countdownItem.title = String(format: "Next change: %d:%02d", mins, secs)
    }

    // MARK: - Menu actions

    @objc private func handleNext() {
        onNext?()
    }

    @objc private func handlePauseToggle() {
        onPauseToggle?()
    }

    @objc private func handlePreferences() {
        onPreferences?()
    }

    @objc private func handleQuit() {
        systemWallpaperStore.restore()
        NSApp.terminate(nil)
    }
}
