import Cocoa

final class AppController: NSObject, NSApplicationDelegate {
    private static let restoreSettingsAfterRelaunchKey =
        "restoreSettingsAfterRelaunch"
    private static let inputMonitoringRestartWarningBundleIdentifier =
        "com.apple.accessibility.universalAccessAuthWarn"
    private static let systemSettingsBundleIdentifier =
        "com.apple.systempreferences"

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
    private var shortcutRefreshWorkItem: DispatchWorkItem?
    private var tccAccessChangedToken: Int32 = -1
    private var ignoreTCCAccessChangesUntil: TimeInterval = 0
    private var isAwaitingInputMonitoringRestartDecision = false
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
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        notify_register_dispatch(
            "com.apple.tcc.access.changed",
            &tccAccessChangedToken,
            .main
        ) { [weak self] _ in
            self?.tccAccessDidChange()
        }
    }

    deinit {
        shortcutRefreshWorkItem?.cancel()
        if tccAccessChangedToken >= 0 {
            notify_cancel(tccAccessChangedToken)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        let shouldRestoreSettings = defaults.bool(
            forKey: Self.restoreSettingsAfterRelaunchKey
        )
        defaults.removeObject(forKey: Self.restoreSettingsAfterRelaunchKey)
        let shouldOpenSettings = shouldRestoreSettings || !wasLaunchedAsLoginItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start(shouldOpenSettings: shouldOpenSettings)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if isAwaitingInputMonitoringRestartDecision {
            isAwaitingInputMonitoringRestartDecision = false
            doubleKeyShortcut.markRestartRequired()
            settingsController?.refresh()
            DispatchQueue.main.async { [weak self] in
                self?.promptToRestartForInputMonitoring()
            }
        }
        refreshShortcutState()
        shortcutRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard NSApp.isActive else { return }
            self?.refreshShortcutState()
        }
        shortcutRefreshWorkItem = workItem
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
            doubleKeyShortcutMonitoringState: { [weak self] in
                self?.doubleKeyShortcut.monitoringState ?? .disabled
            },
            doubleKeyShortcutChanged: { [weak self] change in
                guard let self else { return }
                switch change {
                case .enabled(true):
                    if !DoubleKeyShortcutController.hasMonitoringPermission {
                        ignoreTCCAccessChangesUntil =
                            ProcessInfo.processInfo.systemUptime + 1
                    }
                    let shouldOpenSettings =
                        doubleKeyShortcut.requestMonitoringPermission()
                    let state = updateDoubleKeyShortcut()
                    if state == .failedToStart ||
                       (state == .permissionRequired && shouldOpenSettings) {
                        openInputMonitoringSettings()
                    }
                    settingsController?.refresh()
                case .enabled(false), .configurationChanged:
                    refreshShortcutState()
                }
            },
            menuBarButtonChanged: { [weak self] _ in
                self?.applyMenuBarButtonVisibility()
            },
            dockIconChanged: { [weak self] _ in
                self?.applyDockIconVisibility()
            },
            restart: { [weak self] in
                self?.restart()
            }
        )
    }

    private func restart() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func workspaceApplicationDidActivate(
        _ notification: Notification
    ) {
        guard let application = notification.userInfo?[
            NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication else { return }
        guard application.bundleIdentifier ==
                Self.inputMonitoringRestartWarningBundleIdentifier,
              shouldTrackInputMonitoringChange else { return }
        armInputMonitoringRestartPrompt()
    }

    private func tccAccessDidChange() {
        if ProcessInfo.processInfo.systemUptime <
            ignoreTCCAccessChangesUntil {
            ignoreTCCAccessChangesUntil = 0
            return
        }
        let frontmostBundleIdentifier =
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard frontmostBundleIdentifier ==
                Self.systemSettingsBundleIdentifier,
              shouldTrackInputMonitoringChange else { return }
        armInputMonitoringRestartPrompt()
    }

    private var shouldTrackInputMonitoringChange: Bool {
        preferences.isDoubleKeyShortcutEnabled &&
            settingsController?.window?.isVisible == true
    }

    private func armInputMonitoringRestartPrompt() {
        guard !isAwaitingInputMonitoringRestartDecision else { return }
        isAwaitingInputMonitoringRestartDecision = true
    }

    private func promptToRestartForInputMonitoring() {
        let alert = NSAlert()
        alert.messageText = "Restart Blackout?"
        alert.informativeText =
            "Restart Blackout for the Input Monitoring change to take effect."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            restart()
        }
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

    @discardableResult
    private func updateDoubleKeyShortcut() -> DoubleKeyShortcutMonitoringState {
        doubleKeyShortcut.updateMonitoring()
    }

    @objc private func refreshShortcutState() {
        updateDoubleKeyShortcut()
        settingsController?.refresh()
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
        if settingsController?.window?.isVisible == true {
            UserDefaults.standard.set(
                true,
                forKey: Self.restoreSettingsAfterRelaunchKey
            )
        }
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
