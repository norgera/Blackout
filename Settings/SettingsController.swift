import Cocoa
import SwiftUI

final class SettingsController: NSWindowController {
    private let viewModel: SettingsViewModel
    private var shortcutKeyCaptureMonitor: Any?

    init(
        preferences: PreferencesService,
        launchAtLogin: LaunchAtLoginService,
        toggleBlackout: @escaping () -> Void,
        touchBarButtonChanged: @escaping (Bool) -> Void,
        keyboardBacklightChanged: @escaping (Bool) -> Void,
        doubleKeyShortcutPermissionGranted: @escaping () -> Bool,
        doubleKeyShortcutChanged: @escaping (Bool) -> Void,
        menuBarButtonChanged: @escaping (Bool) -> Void,
        dockIconChanged: @escaping (Bool) -> Void
    ) {
        viewModel = SettingsViewModel(
            preferences: preferences,
            launchAtLogin: launchAtLogin,
            toggleBlackout: toggleBlackout,
            touchBarButtonChanged: touchBarButtonChanged,
            keyboardBacklightChanged: keyboardBacklightChanged,
            doubleKeyShortcutPermissionGranted: doubleKeyShortcutPermissionGranted,
            doubleKeyShortcutChanged: doubleKeyShortcutChanged,
            menuBarButtonChanged: menuBarButtonChanged,
            dockIconChanged: dockIconChanged,
            quit: { NSApp.terminate(nil) }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 590),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Blackout Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.contentViewController = NSHostingController(
            rootView: SettingsView(model: viewModel)
        )
        viewModel.chooseShortcutKeyAction = { [weak self] in
            self?.startCapturingShortcutKey()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshFromSystem),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelShortcutKeyCapture),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopCapturingShortcutKey()
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        guard let window else { return }
        window.setIsVisible(true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(sender)
        window.orderFrontRegardless()
    }

    func refresh() {
        viewModel.refresh()
    }

    @objc private func refreshFromSystem() {
        refresh()
    }

    private func startCapturingShortcutKey() {
        stopCapturingShortcutKey()
        shortcutKeyCaptureMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .keyDown,
                .flagsChanged,
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown
            ]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown ||
                event.type == .rightMouseDown ||
                event.type == .otherMouseDown {
                cancelShortcutKeyCapture()
                return event
            }
            viewModel.recordShortcutKey(
                code: event.keyCode,
                name: DoubleKeyShortcutKey.name(for: event)
            )
            stopCapturingShortcutKey()
            return nil
        }
    }

    @objc private func cancelShortcutKeyCapture() {
        stopCapturingShortcutKey()
        viewModel.cancelRecordingShortcutKey()
    }

    private func stopCapturingShortcutKey() {
        if let shortcutKeyCaptureMonitor {
            NSEvent.removeMonitor(shortcutKeyCaptureMonitor)
            self.shortcutKeyCaptureMonitor = nil
        }
    }
}
