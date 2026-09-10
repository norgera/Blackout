import Cocoa
import ApplicationServices
import IOKit.hidsystem

final class DoubleKeyShortcutController {
    private let preferences: PreferencesService
    private let toggleHandler: () -> Void
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var lastPressTimestamp: TimeInterval?

    init(
        preferences: PreferencesService,
        toggleHandler: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.toggleHandler = toggleHandler
    }

    deinit {
        removeEventTap()
    }

    var isMonitoring: Bool {
        guard preferences.isDoubleKeyShortcutEnabled,
              preferences.doubleKeyShortcutKeyCode != nil,
              Self.hasMonitoringPermission,
              let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func updateMonitoring() {
        guard preferences.isDoubleKeyShortcutEnabled,
              preferences.doubleKeyShortcutKeyCode != nil else {
            removeEventTap()
            return
        }

        guard Self.hasMonitoringPermission else {
            removeEventTap()
            return
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return
        }
        let eventMask = CGEventMask(1) << CGEventType.keyDown.rawValue |
            CGEventMask(1) << CGEventType.flagsChanged.rawValue
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }
        let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        )
        self.eventTap = eventTap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    static var hasMonitoringPermission: Bool {
        if #available(macOS 10.15, *) {
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) ==
                kIOHIDAccessTypeGranted
        }
        return AXIsProcessTrusted()
    }

    func requestMonitoringPermission() {
        guard !Self.hasMonitoringPermission else { return }
        if #available(macOS 10.15, *) {
            // Make the running app discoverable by the permission settings UI.
            _ = LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
            let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            if access == kIOHIDAccessTypeDenied, eventTap != nil {
                removeEventTap()
            }
            switch access {
            case kIOHIDAccessTypeUnknown:
                _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            case kIOHIDAccessTypeDenied:
                showPermissionRestartAlert()
            default:
                break
            }
            return
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [promptKey as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @available(macOS 10.15, *)
    private func showPermissionRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Restart Blackout"
        alert.informativeText = "Restart Blackout for changes in System Settings to take effect."
        alert.addButton(withTitle: "Quit & Reopen")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            DispatchQueue.main.async {
                guard error == nil else {
                    Self.showRelaunchError(error)
                    return
                }
                NSApp.windows.forEach { $0.orderOut(nil) }
                NSApp.terminate(nil)
            }
        }
    }

    private static func showRelaunchError(_ error: Error?) {
        let alert = NSAlert()
        alert.messageText = "Blackout could not reopen"
        alert.informativeText = error?.localizedDescription ??
            "Quit and reopen Blackout manually."
        alert.runModal()
    }

    private static let eventTapCallback: CGEventTapCallBack = {
        _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let controller = Unmanaged<DoubleKeyShortcutController>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = controller.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        } else if let event = NSEvent(cgEvent: event) {
            controller.handle(event)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handle(_ event: NSEvent) {
        guard preferences.isDoubleKeyShortcutEnabled,
              let keyCode = preferences.doubleKeyShortcutKeyCode,
              event.keyCode == keyCode else {
            lastPressTimestamp = nil
            return
        }

        if event.type == .keyDown, event.isARepeat {
            lastPressTimestamp = nil
            return
        }

        guard isKeyPress(event) else { return }

        if let lastPressTimestamp,
           event.timestamp - lastPressTimestamp <= preferences.doubleKeyShortcutInterval {
            self.lastPressTimestamp = nil
            DispatchQueue.main.async { [toggleHandler] in
                toggleHandler()
            }
        } else {
            lastPressTimestamp = event.timestamp
        }
    }

    private func removeEventTap() {
        if let eventTapSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                eventTapSource,
                .commonModes
            )
            self.eventTapSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        lastPressTimestamp = nil
    }

    private func isKeyPress(_ event: NSEvent) -> Bool {
        guard event.type == .flagsChanged else { return true }
        guard let modifier = DoubleKeyShortcutKey.modifiers[event.keyCode] else {
            return false
        }
        if modifier.flag == .capsLock { return true }
        return event.modifierFlags.contains(modifier.flag)
    }
}

enum DoubleKeyShortcutKey {
    struct Modifier {
        let flag: NSEvent.ModifierFlags
        let name: String
    }

    static let modifiers: [UInt16: Modifier] = [
        54: Modifier(flag: .command, name: "Command"),
        55: Modifier(flag: .command, name: "Command"),
        56: Modifier(flag: .shift, name: "Shift"),
        57: Modifier(flag: .capsLock, name: "Caps Lock"),
        58: Modifier(flag: .option, name: "Option"),
        59: Modifier(flag: .control, name: "Control"),
        60: Modifier(flag: .shift, name: "Shift"),
        61: Modifier(flag: .option, name: "Option"),
        62: Modifier(flag: .control, name: "Control"),
        63: Modifier(flag: .function, name: "Fn")
    ]

    static func name(for event: NSEvent) -> String {
        if let modifier = modifiers[event.keyCode] {
            return modifier.name
        }
        if let characters = event.charactersIgnoringModifiers,
           !characters.isEmpty,
           characters.unicodeScalars.allSatisfy({
               !CharacterSet.controlCharacters.contains($0)
           }) {
            return characters.uppercased()
        }
        return "Key \(event.keyCode)"
    }
}
