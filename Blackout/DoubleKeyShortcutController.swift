import Cocoa
import ApplicationServices
import IOKit.hidsystem

enum DoubleKeyShortcutChange {
    case enabled(Bool)
    case configurationChanged
}

enum DoubleKeyShortcutMonitoringState: Equatable {
    case disabled
    case missingKey
    case permissionRequired
    case active
    case restartRequired
    case failedToStart
}

final class DoubleKeyShortcutController {
    private let preferences: PreferencesService
    private let toggleHandler: () -> Void
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var lastPressTimestamp: TimeInterval?
    private var requiresRestartForSystemChange = false
    private(set) var monitoringState = DoubleKeyShortcutMonitoringState.disabled

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

    @discardableResult
    func updateMonitoring() -> DoubleKeyShortcutMonitoringState {
        guard preferences.isDoubleKeyShortcutEnabled else {
            removeEventTap()
            monitoringState = .disabled
            return monitoringState
        }

        guard preferences.doubleKeyShortcutKeyCode != nil else {
            removeEventTap()
            monitoringState = .missingKey
            return monitoringState
        }

        if requiresRestartForSystemChange {
            monitoringState = .restartRequired
            return monitoringState
        }

        guard Self.hasMonitoringPermission else {
            removeEventTap()
            monitoringState = .permissionRequired
            return monitoringState
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            if CGEvent.tapIsEnabled(tap: eventTap) {
                monitoringState = .active
                return monitoringState
            }
            removeEventTap()
            monitoringState = .failedToStart
            return monitoringState
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
            monitoringState = .failedToStart
            return monitoringState
        }
        guard let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            monitoringState = .failedToStart
            return monitoringState
        }
        self.eventTap = eventTap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        guard CGEvent.tapIsEnabled(tap: eventTap) else {
            removeEventTap()
            monitoringState = .failedToStart
            return monitoringState
        }
        monitoringState = .active
        return monitoringState
    }

    func markRestartRequired() {
        guard preferences.isDoubleKeyShortcutEnabled else { return }
        requiresRestartForSystemChange = true
        monitoringState = .restartRequired
    }

    static var hasMonitoringPermission: Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return AXIsProcessTrusted()
    }

    @discardableResult
    func requestMonitoringPermission() -> Bool {
        guard preferences.isDoubleKeyShortcutEnabled,
              !Self.hasMonitoringPermission else { return false }
        if #available(macOS 10.15, *) {
            let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            // Make the running app discoverable by the permission settings UI.
            _ = LSRegisterURL(
                Bundle.main.bundleURL as CFURL,
                true
            )
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            return access == kIOHIDAccessTypeDenied
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [promptKey as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
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
                let hasPermission =
                    DoubleKeyShortcutController.hasMonitoringPermission
                if CGEvent.tapIsEnabled(tap: eventTap) {
                    controller.monitoringState = hasPermission ?
                        .active : .permissionRequired
                } else {
                    controller.monitoringState = hasPermission ?
                        .failedToStart : .permissionRequired
                }
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
