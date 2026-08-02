import Foundation

final class PreferencesService {
    static let shared = PreferencesService()

    private enum Key {
        static let touchBarButton = "showTouchBarButton"
        static let includesKeyboardBacklight = "syncKeyboardBacklight"
        static let menuBarButton = "showMenuBarButton"
        static let dockIcon = "showDockIcon"
    }

    var isTouchBarButtonEnabled: Bool {
        get { bool(for: Key.touchBarButton, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.touchBarButton) }
    }

    var includesKeyboardBacklight: Bool {
        get { bool(for: Key.includesKeyboardBacklight, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.includesKeyboardBacklight) }
    }

    var isMenuBarButtonEnabled: Bool {
        get { bool(for: Key.menuBarButton, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.menuBarButton) }
    }

    var isDockIconEnabled: Bool {
        get { bool(for: Key.dockIcon, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: Key.dockIcon) }
    }

    private func bool(for key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }
}
