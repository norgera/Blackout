import Cocoa

final class AppController: NSObject, NSApplicationDelegate {
    private let preferences = PreferencesService.shared
    private let blackoutService = BlackoutService()
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )
    private lazy var doubleKeyShortcut = DoubleKeyShortcutController(
        preferences: preferences,
        toggleHandler: { [weak self] in
            self?.blackoutService.toggle()
        }
    )
    private var settingsController: SettingsController?
    private var isAwaitingAccessibilityPermission = false
    private var accessibilityRefreshWorkItem: DispatchWorkItem?
    private let includeKeyboardMenuItem = NSMenuItem(
        title: "Include keyboard backlight",
        action: #selector(toggleKeyboardSync),
        keyEquivalent: ""
    )

    override init() {
        super.init()
        blackoutService.recoverInterruptedKeyboardBacklightIfNeeded()
        if let button = statusItem.button {
            button.image = BlackoutIcon.image()
            button.imagePosition = .imageOnly
            button.toolTip = "Touch Bar Blackout"
        }
        blackoutService.configureTouchBarActions()
        configureMenu()
        applyMenuBarButtonVisibility()
        applyDockIconVisibility()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(restoreBeforeSystemTransition),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(restoreBeforeSystemTransition),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }

    deinit {
        accessibilityRefreshWorkItem?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shouldOpenSettings = !wasLaunchedAsLoginItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start(shouldOpenSettings: shouldOpenSettings)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshAccessibilityState()
        accessibilityRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard NSApp.isActive else { return }
            self?.refreshAccessibilityState()
        }
        accessibilityRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.75,
            execute: workItem
        )
    }

    private func start(shouldOpenSettings: Bool) {
        updateDoubleKeyShortcut()
        if preferences.isTouchBarButtonEnabled {
            blackoutService.installTouchBarButton()
        }
        updateIncludeKeyboardMenuItem()
        if shouldOpenSettings {
            openSettings()
        }
    }

    private func configureMenu() {
        let menu = NSMenu()
        let blackoutItem = NSMenuItem(
            title: "Toggle blackout",
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
        blackoutService.applyKeyboardBacklightPreference()
        updateIncludeKeyboardMenuItem()
        settingsController?.refresh()
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
                self?.blackoutService.applyKeyboardBacklightPreference()
                self?.updateIncludeKeyboardMenuItem()
            },
            doubleKeyShortcutPermissionGranted: {
                DoubleKeyShortcutController.hasAccessibilityPermission
            },
            doubleKeyShortcutChanged: { [weak self] shouldRequestAccess in
                if shouldRequestAccess {
                    self?.isAwaitingAccessibilityPermission =
                        !DoubleKeyShortcutController.hasAccessibilityPermission
                    self?.ensureAccessibilityPermission()
                } else {
                    self?.isAwaitingAccessibilityPermission = false
                }
                self?.updateDoubleKeyShortcut()
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

    private func updateDoubleKeyShortcut() {
        doubleKeyShortcut.updateMonitoring()
    }

    private func refreshAccessibilityState() {
        let isPermissionGranted =
            DoubleKeyShortcutController.hasAccessibilityPermission
        if isPermissionGranted && isAwaitingAccessibilityPermission {
            preferences.isDoubleKeyShortcutEnabled = true
            isAwaitingAccessibilityPermission = false
        }
        updateDoubleKeyShortcut()
        settingsController?.refresh()
    }

    private func ensureAccessibilityPermission() {
        guard !DoubleKeyShortcutController.hasAccessibilityPermission else {
            isAwaitingAccessibilityPermission = false
            return
        }
        DoubleKeyShortcutController.requestAccessibilityPermission()
    }

    private var wasLaunchedAsLoginItem: Bool {
        if CommandLine.arguments.contains("--launched-at-login") {
            return true
        }
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return false
        }
        return event.eventID == kAEOpenApplication &&
            event.paramDescriptor(
                forKeyword: keyAEPropData
            )?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    @objc private func restoreBeforeSystemTransition() {
        blackoutService.restore()
    }

    func applicationWillTerminate(_ notification: Notification) {
        blackoutService.restore()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        openSettings()
        return true
    }
}
