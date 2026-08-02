import Cocoa

final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()
    private let trayIdentifier = NSTouchBarItem.Identifier("com.blackout.tray")
    private let blackoutIdentifier = NSTouchBarItem.Identifier("com.blackout.blackout")
    private var trayItem: NSCustomTouchBarItem?
    private var blackoutBar: NSTouchBar?
    private(set) var isBlackoutActive = false
    var toggleHandler: (() -> Void)?
    var blackoutDismissedHandler: (() -> Void)?

    @discardableResult
    func installTouchBarToggle() -> Bool {
        guard PrivateTouchBarBridge.isSupported() else { return false }
        if trayItem != nil {
            PrivateTouchBarBridge.setControlStripPresence(
                true,
                identifier: trayIdentifier.rawValue
            )
            return true
        }
        let item = NSCustomTouchBarItem(identifier: trayIdentifier)
        let button = NSButton(
            title: "",
            target: self,
            action: #selector(toggleFromTouchBar)
        )
        button.bezelStyle = .rounded
        button.image = BlackoutIcon.image()
        button.imagePosition = .imageOnly
        button.toolTip = "Toggle blackout"
        button.frame = NSRect(x: 0, y: 0, width: 44, height: 30)
        item.view = button
        trayItem = item
        PrivateTouchBarBridge.addSystemTrayItem(item)
        PrivateTouchBarBridge.setControlStripPresence(
            true,
            identifier: trayIdentifier.rawValue
        )
        return true
    }

    func uninstallTouchBarToggle() {
        guard trayItem != nil else { return }
        PrivateTouchBarBridge.setControlStripPresence(
            false,
            identifier: trayIdentifier.rawValue
        )
    }

    func toggle() {
        isBlackoutActive ? dismissBlackout() : presentBlackout()
    }

    @objc private func toggleFromTouchBar(_ sender: Any?) {
        if let toggleHandler {
            toggleHandler()
        } else {
            toggle()
        }
    }

    @objc private func restoreFromBlackout(_ sender: Any?) {
        dismissBlackout()
    }

    private func presentBlackout() {
        guard !isBlackoutActive else { return }
        PrivateTouchBarBridge.setSystemModalCloseBoxVisible(false)
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            blackoutIdentifier
        ]
        bar.principalItemIdentifier = blackoutIdentifier
        blackoutBar = bar
        isBlackoutActive =
            PrivateTouchBarBridge.presentSystemModalTouchBar(
                bar,
                placement: 1
            )
    }

    private func dismissBlackout() {
        guard isBlackoutActive, let blackoutBar else { return }
        PrivateTouchBarBridge.dismissSystemModalTouchBar(blackoutBar)
        self.blackoutBar = nil
        isBlackoutActive = false
        blackoutDismissedHandler?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restoreTouchBarToggle()
        }
    }

    private func restoreTouchBarToggle() {
        guard let trayItem else { return }
        PrivateTouchBarBridge.setControlStripPresence(
            false,
            identifier: trayIdentifier.rawValue
        )
        PrivateTouchBarBridge.removeSystemTrayItem(trayItem)
        PrivateTouchBarBridge.addSystemTrayItem(trayItem)
        PrivateTouchBarBridge.setControlStripPresence(
            true,
            identifier: trayIdentifier.rawValue
        )
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == blackoutIdentifier else {
            return nil
        }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = BlackoutButton(
            title: "",
            target: self,
            action: #selector(restoreFromBlackout(_:))
        )
        button.isBordered = false
        button.focusRingType = .none
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = button.widthAnchor.constraint(
            greaterThanOrEqualToConstant: 1000
        )
        NSLayoutConstraint.activate([
            widthConstraint,
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        item.view = button
        return item
    }
}

private final class BlackoutButton: NSButton {
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        sendAction(action, to: target)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 0
        layer?.borderWidth = 0
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
    }
}
