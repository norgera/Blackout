import Cocoa

final class SettingsController: NSWindowController {
    private let preferences: PreferencesService
    private let launchAtLogin: LaunchAtLoginService
    private let toggleBlackout: () -> Void
    private let touchBarButtonChanged: (Bool) -> Void
    private let keyboardBacklightChanged: (Bool) -> Void
    private let menuBarButtonChanged: (Bool) -> Void
    private let dockIconChanged: (Bool) -> Void
    private let touchBarButton = NSButton(
        checkboxWithTitle: "Show touch bar button", target: nil, action: nil
    )
    private let toggleBlackoutButton = NSButton(
        title: "Toggle Blackout", target: nil, action: nil
    )
    private let keyboardBacklightButton = NSButton(
        checkboxWithTitle: "Include Keyboard Backlight", target: nil, action: nil
    )
    private let launchAtLoginButton = NSButton(
        checkboxWithTitle: "Start at login", target: nil, action: nil
    )
    private let menuBarButton = NSButton(
        checkboxWithTitle: "Show menu bar button", target: nil, action: nil
    )
    private let dockIconButton = NSButton(
        checkboxWithTitle: "Show app in dock", target: nil, action: nil
    )
    private let quitButton = NSButton(title: "Quit Blackout", target: nil, action: nil)

    init(
        preferences: PreferencesService,
        launchAtLogin: LaunchAtLoginService,
        toggleBlackout: @escaping () -> Void,
        touchBarButtonChanged: @escaping (Bool) -> Void,
        keyboardBacklightChanged: @escaping (Bool) -> Void,
        menuBarButtonChanged: @escaping (Bool) -> Void,
        dockIconChanged: @escaping (Bool) -> Void
    ) {
        self.preferences = preferences
        self.launchAtLogin = launchAtLogin
        self.toggleBlackout = toggleBlackout
        self.touchBarButtonChanged = touchBarButtonChanged
        self.keyboardBacklightChanged = keyboardBacklightChanged
        self.menuBarButtonChanged = menuBarButtonChanged
        self.dockIconChanged = dockIconChanged
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 340),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "Blackout Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        configureContent(in: window)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshFromSystem),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        guard let window else { return }
        window.setIsVisible(true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(sender)
        window.orderFrontRegardless()
    }

    private func configureContent(in window: NSWindow) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sectionLabel("Controls"))
        stack.addArrangedSubview(toggleBlackoutButton)
        stack.addArrangedSubview(touchBarButton)
        stack.addArrangedSubview(keyboardBacklightButton)
        stack.addArrangedSubview(menuBarButton)
        stack.addArrangedSubview(dockIconButton)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionLabel("Startup"))
        stack.addArrangedSubview(launchAtLoginButton)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(quitButton)
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -22)
        ])
        touchBarButton.target = self
        touchBarButton.action = #selector(touchBarButtonChangedAction)
        toggleBlackoutButton.target = self
        toggleBlackoutButton.action = #selector(toggleBlackoutAction)
        keyboardBacklightButton.target = self
        keyboardBacklightButton.action = #selector(keyboardBacklightChangedAction)
        menuBarButton.target = self
        menuBarButton.action = #selector(menuBarButtonChangedAction)
        dockIconButton.target = self
        dockIconButton.action = #selector(dockIconButtonChangedAction)
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        quitButton.target = self
        quitButton.action = #selector(quit)
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 332).isActive = true
        return separator
    }

    private func refresh() {
        touchBarButton.state = preferences.isTouchBarButtonEnabled ? .on : .off
        keyboardBacklightButton.state = preferences.includesKeyboardBacklight ? .on : .off
        menuBarButton.state = preferences.isMenuBarButtonEnabled ? .on : .off
        dockIconButton.state = preferences.isDockIconEnabled ? .on : .off
        launchAtLoginButton.isEnabled = launchAtLogin.isAvailable
        launchAtLoginButton.state = launchAtLogin.isEnabled ? .on : .off
    }

    func syncWithPreferences() {
        refresh()
    }

    @objc private func refreshFromSystem() {
        refresh()
    }

    @objc private func touchBarButtonChangedAction() {
        preferences.isTouchBarButtonEnabled = touchBarButton.state == .on
        touchBarButtonChanged(preferences.isTouchBarButtonEnabled)
    }

    @objc private func toggleBlackoutAction() {
        toggleBlackout()
    }

    @objc private func keyboardBacklightChangedAction() {
        preferences.includesKeyboardBacklight = keyboardBacklightButton.state == .on
        keyboardBacklightChanged(preferences.includesKeyboardBacklight)
    }

    @objc private func menuBarButtonChangedAction() {
        preferences.isMenuBarButtonEnabled = menuBarButton.state == .on
        menuBarButtonChanged(preferences.isMenuBarButtonEnabled)
        refresh()
    }

    @objc private func dockIconButtonChangedAction() {
        preferences.isDockIconEnabled = dockIconButton.state == .on
        dockIconChanged(preferences.isDockIconEnabled)
        refresh()
    }

    @objc private func launchAtLoginChanged() {
        launchAtLogin.setEnabled(launchAtLoginButton.state == .on)
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
