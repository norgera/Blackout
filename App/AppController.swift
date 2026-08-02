import Cocoa

final class AppController: NSObject, NSApplicationDelegate {
    private let preferences = PreferencesService.shared
    private let blackoutService = BlackoutService()
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private var settingsController: SettingsController?
    private let includeKeyboardMenuItem = NSMenuItem(
        title: "Include Keyboard Backlight",
        action: #selector(toggleKeyboardSync),
        keyEquivalent: ""
    )

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = BlackoutIcon.image()
            button.imagePosition = .imageOnly
            button.toolTip = "Touch Bar Blackout"
        }
        blackoutService.configureTouchBarActions()
        configureMenu()
        applyMenuBarButtonVisibility()
        applyDockIconVisibility()
    }

    func start() {
        if preferences.isTouchBarButtonEnabled {
            blackoutService.installTouchBarButton()
        }
        updateIncludeKeyboardMenuItem()
        openSettings()
    }

    private func configureMenu() {
        let menu = NSMenu()
        let blackoutItem = NSMenuItem(
            title: "Toggle Blackout",
            action: #selector(toggleBlackout),
            keyEquivalent: ""
        )
        blackoutItem.target = self
        menu.addItem(blackoutItem)
        includeKeyboardMenuItem.target = self
        menu.addItem(includeKeyboardMenuItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Blackout",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func toggleBlackout() {
        blackoutService.toggle()
    }

    @objc private func toggleKeyboardSync() {
        preferences.includesKeyboardBacklight.toggle()
        updateIncludeKeyboardMenuItem()
        settingsController?.syncWithPreferences()
    }

    private func updateIncludeKeyboardMenuItem() {
        includeKeyboardMenuItem.state =
            preferences.includesKeyboardBacklight ? .on : .off
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = makeSettingsController()
        }
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeSettingsController() -> SettingsController {
        SettingsController(
            preferences: preferences,
            launchAtLogin: .shared,
            toggleBlackout: { [weak self] in
                self?.blackoutService.toggle()
            },
            touchBarButtonChanged: { [weak self] in
                self?.applyTouchBarButtonVisibility($0)
            },
            keyboardBacklightChanged: { [weak self] _ in
                self?.updateIncludeKeyboardMenuItem()
            },
            menuBarButtonChanged: { [weak self] _ in
                self?.applyMenuBarButtonVisibility()
            },
            dockIconChanged: { [weak self] _ in
                self?.applyDockIconVisibility()
            }
        )
    }

    private func applyTouchBarButtonVisibility(_ enabled: Bool) {
        if enabled {
            blackoutService.installTouchBarButton()
        } else {
            blackoutService.uninstallTouchBarButton()
        }
    }

    private func applyMenuBarButtonVisibility() {
        statusItem.isVisible = preferences.isMenuBarButtonEnabled
    }

    private func applyDockIconVisibility() {
        let showDockIcon = preferences.isDockIconEnabled
        _ = NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if !showDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        openSettings()
        return true
    }
}
