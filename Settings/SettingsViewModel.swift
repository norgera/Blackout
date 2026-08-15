import Foundation

final class SettingsViewModel: ObservableObject {
    private let preferences: PreferencesService
    private let launchAtLogin: LaunchAtLoginService
    private let updateService = UpdateService()
    private let toggleBlackoutAction: () -> Void
    private let touchBarButtonChanged: (Bool) -> Void
    private let keyboardBacklightChanged: (Bool) -> Void
    private let doubleKeyShortcutMonitoringState: () -> DoubleKeyShortcutMonitoringState
    private let doubleKeyShortcutChanged: (DoubleKeyShortcutChange) -> Void
    private let menuBarButtonChanged: (Bool) -> Void
    private let dockIconChanged: (Bool) -> Void
    private let quitAction: () -> Void

    @Published private(set) var isTouchBarButtonEnabled = true
    @Published private(set) var isTouchBarTapToRestoreEnabled = true
    @Published private(set) var includesKeyboardBacklight = true
    @Published private(set) var isDoubleKeyShortcutEnabled = false
    @Published private(set) var shortcutMonitoringState =
        DoubleKeyShortcutMonitoringState.disabled
    @Published private(set) var shortcutKeyName: String?
    @Published private(set) var shortcutInterval: TimeInterval = 0.35
    @Published private(set) var isMenuBarButtonEnabled = true
    @Published private(set) var isDockIconEnabled = false
    @Published private(set) var isLaunchAtLoginAvailable = false
    @Published private(set) var isLaunchAtLoginEnabled = false
    @Published private(set) var isRecordingShortcutKey = false
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var updateStatus: String?
    @Published private(set) var availableUpdateURL: URL?

    var chooseShortcutKeyAction: (() -> Void)?

    init(
        preferences: PreferencesService,
        launchAtLogin: LaunchAtLoginService,
        toggleBlackout: @escaping () -> Void,
        touchBarButtonChanged: @escaping (Bool) -> Void,
        keyboardBacklightChanged: @escaping (Bool) -> Void,
        doubleKeyShortcutMonitoringState: @escaping () -> DoubleKeyShortcutMonitoringState,
        doubleKeyShortcutChanged: @escaping (DoubleKeyShortcutChange) -> Void,
        menuBarButtonChanged: @escaping (Bool) -> Void,
        dockIconChanged: @escaping (Bool) -> Void,
        quit: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.launchAtLogin = launchAtLogin
        self.toggleBlackoutAction = toggleBlackout
        self.touchBarButtonChanged = touchBarButtonChanged
        self.keyboardBacklightChanged = keyboardBacklightChanged
        self.doubleKeyShortcutMonitoringState =
            doubleKeyShortcutMonitoringState
        self.doubleKeyShortcutChanged = doubleKeyShortcutChanged
        self.menuBarButtonChanged = menuBarButtonChanged
        self.dockIconChanged = dockIconChanged
        self.quitAction = quit
        refresh()
    }

    var shortcutButtonTitle: String {
        if isRecordingShortcutKey { return "Press a key…" }
        guard let shortcutKeyName else { return "Choose key…" }
        return "Double-press \(shortcutKeyName)"
    }

    var shortcutIntervalTitle: String {
        String(format: "%.2f sec", shortcutInterval)
    }

    var shortcutStatus: String? {
        guard isDoubleKeyShortcutEnabled else { return nil }
        switch shortcutMonitoringState {
        case .disabled:
            return nil
        case .missingKey:
            return "Choose a trigger key."
        case .permissionRequired:
            return "Allow Blackout in Privacy & Security → Input Monitoring."
        case .active:
            return "Keyboard monitor active."
        case .failedToStart:
            return "Permission is allowed, but the keyboard monitor could " +
                "not start. Quit and reopen Blackout."
        }
    }

    var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
    }

    var versionTitle: String {
        "Version \(version)"
    }

    func refresh() {
        isTouchBarButtonEnabled = preferences.isTouchBarButtonEnabled
        isTouchBarTapToRestoreEnabled = preferences.isTouchBarTapToRestoreEnabled
        includesKeyboardBacklight = preferences.includesKeyboardBacklight
        isDoubleKeyShortcutEnabled = preferences.isDoubleKeyShortcutEnabled
        shortcutMonitoringState = doubleKeyShortcutMonitoringState()
        shortcutKeyName = preferences.doubleKeyShortcutKeyName
        shortcutInterval = preferences.doubleKeyShortcutInterval
        isMenuBarButtonEnabled = preferences.isMenuBarButtonEnabled
        isDockIconEnabled = preferences.isDockIconEnabled
        isLaunchAtLoginAvailable = launchAtLogin.isAvailable
        isLaunchAtLoginEnabled = launchAtLogin.isEnabled
    }

    func toggleBlackout() {
        toggleBlackoutAction()
    }

    func setTouchBarButtonEnabled(_ enabled: Bool) {
        preferences.isTouchBarButtonEnabled = enabled
        isTouchBarButtonEnabled = preferences.isTouchBarButtonEnabled
        touchBarButtonChanged(isTouchBarButtonEnabled)
    }

    func setTouchBarTapToRestoreEnabled(_ enabled: Bool) {
        preferences.isTouchBarTapToRestoreEnabled = enabled
        isTouchBarTapToRestoreEnabled = preferences.isTouchBarTapToRestoreEnabled
    }

    func setIncludesKeyboardBacklight(_ enabled: Bool) {
        preferences.includesKeyboardBacklight = enabled
        includesKeyboardBacklight = preferences.includesKeyboardBacklight
        keyboardBacklightChanged(includesKeyboardBacklight)
    }

    func setDoubleKeyShortcutEnabled(_ enabled: Bool) {
        // Persist the user's intent independently of the current TCC state.
        // The old implementation wrote `false` before opening System Settings,
        // so a restart or missed activation callback permanently lost the
        // request to enable the shortcut.
        preferences.isDoubleKeyShortcutEnabled = enabled
        isDoubleKeyShortcutEnabled = preferences.isDoubleKeyShortcutEnabled
        doubleKeyShortcutChanged(.enabled(enabled))
    }

    func beginRecordingShortcutKey() {
        isRecordingShortcutKey = true
        chooseShortcutKeyAction?()
    }

    func cancelRecordingShortcutKey() {
        isRecordingShortcutKey = false
    }

    func recordShortcutKey(code: UInt16, name: String) {
        preferences.doubleKeyShortcutKeyCode = code
        preferences.doubleKeyShortcutKeyName = name
        isRecordingShortcutKey = false
        shortcutKeyName = preferences.doubleKeyShortcutKeyName
        doubleKeyShortcutChanged(.configurationChanged)
    }

    func setShortcutInterval(_ interval: TimeInterval) {
        preferences.doubleKeyShortcutInterval = interval
        shortcutInterval = preferences.doubleKeyShortcutInterval
    }

    func setMenuBarButtonEnabled(_ enabled: Bool) {
        preferences.isMenuBarButtonEnabled = enabled
        isMenuBarButtonEnabled = preferences.isMenuBarButtonEnabled
        menuBarButtonChanged(isMenuBarButtonEnabled)
    }

    func setDockIconEnabled(_ enabled: Bool) {
        preferences.isDockIconEnabled = enabled
        isDockIconEnabled = preferences.isDockIconEnabled
        dockIconChanged(isDockIconEnabled)
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLogin.setEnabled(enabled)
        isLaunchAtLoginEnabled = launchAtLogin.isEnabled
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateStatus = nil
        availableUpdateURL = nil
        updateService.check(currentVersion: version) { [weak self] result in
            guard let self else { return }
            isCheckingForUpdates = false
            switch result {
            case .upToDate:
                updateStatus = "Blackout is up to date."
            case let .updateAvailable(version, url):
                updateStatus = "\(version) is available."
                availableUpdateURL = url
            case .noPublishedRelease:
                updateStatus = "No releases have been published yet."
            case .failed:
                updateStatus = "Unable to check for updates."
            }
        }
    }

    func quit() {
        quitAction()
    }
}
