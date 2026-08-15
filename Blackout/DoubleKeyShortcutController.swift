import Cocoa
import ApplicationServices

enum DoubleKeyShortcutChange {
    case enabled(Bool)
    case configurationChanged
}

enum DoubleKeyShortcutMonitoringState: Equatable {
    case disabled
    case missingKey
    case permissionRequired
    case active
    case failedToStart
}

final class DoubleKeyShortcutController {
    private let preferences: PreferencesService
    private let toggleHandler: () -> Void
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var lastPressTimestamp: TimeInterval?
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

        guard Self.hasKeyboardMonitoringPermission else {
            removeEventTap()
            monitoringState = .permissionRequired
            return monitoringState
        }

        if let eventTap {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            monitoringState = .active
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
        let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        )
        self.eventTap = eventTap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        monitoringState = .active
        return monitoringState
    }

    static var hasKeyboardMonitoringPermission: Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return AXIsProcessTrusted()
    }

    static func requestKeyboardMonitoringPermission() {
        guard !hasKeyboardMonitoringPermission else { return }
        if #available(macOS 10.15, *) {
            _ = CGRequestListenEventAccess()
            return
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [promptKey as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
