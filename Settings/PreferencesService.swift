import Foundation

final class PreferencesService {
    static let shared = PreferencesService()

    private enum Key {
        static let migratedLegacyBundleDefaults = "migratedLegacyBundleDefaults"
        static let touchBarButton = "showTouchBarButton"
        static let touchBarTapToRestore = "touchBarTapToRestore"
        static let includesKeyboardBacklight = "syncKeyboardBacklight"
        static let menuBarButton = "showMenuBarButton"
        static let dockIcon = "showDockIcon"
        static let doubleKeyShortcutEnabled = "doubleKeyShortcutEnabled"
        static let doubleKeyShortcutKeyCode = "doubleKeyShortcutKeyCode"
        static let doubleKeyShortcutKeyName = "doubleKeyShortcutKeyName"
        static let doubleKeyShortcutInterval = "doubleKeyShortcutInterval"
    }

    private init() {
        migrateLegacyBundleDefaultsIfNeeded()
    }

    var isTouchBarButtonEnabled: Bool {
        get { bool(for: Key.touchBarButton, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.touchBarButton) }
    }

    var isTouchBarTapToRestoreEnabled: Bool {
        get { bool(for: Key.touchBarTapToRestore, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.touchBarTapToRestore) }
    }

    var includesKeyboardBacklight: Bool {
        get { bool(for: Key.includesKeyboardBacklight, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: Key.includesKeyboardBacklight) }
    }

    var isMenuBarButtonEnabled: Bool {
        get { bool(for: Key.menuBarButton, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.menuBarButton) }
    }

    var isDockIconEnabled: Bool {
        get { bool(for: Key.dockIcon, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: Key.dockIcon) }
    }

    var isDoubleKeyShortcutEnabled: Bool {
        get { bool(for: Key.doubleKeyShortcutEnabled, default: false) }
        set { UserDefaults.standard.set(newValue, forKey: Key.doubleKeyShortcutEnabled) }
    }

    var doubleKeyShortcutKeyCode: UInt16? {
        get {
            (UserDefaults.standard.object(
                forKey: Key.doubleKeyShortcutKeyCode
            ) as? NSNumber)?.uint16Value
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Key.doubleKeyShortcutKeyCode)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.doubleKeyShortcutKeyCode)
            }
        }
    }

    var doubleKeyShortcutKeyName: String? {
        get { UserDefaults.standard.string(forKey: Key.doubleKeyShortcutKeyName) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Key.doubleKeyShortcutKeyName)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.doubleKeyShortcutKeyName)
            }
        }
    }

    var doubleKeyShortcutInterval: TimeInterval {
        get {
            let value = UserDefaults.standard.object(
                forKey: Key.doubleKeyShortcutInterval
            ) as? NSNumber
            return value?.doubleValue ?? 0.35
        }
        set {
            UserDefaults.standard.set(
                min(max(newValue, 0.15), 1),
                forKey: Key.doubleKeyShortcutInterval
            )
        }
    }

    private func bool(for key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    private func migrateLegacyBundleDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Key.migratedLegacyBundleDefaults) else {
            return
        }
        let legacyDefaults = UserDefaults(suiteName: "com.example.Blackout")
        let keys = [
            Key.touchBarButton,
            Key.touchBarTapToRestore,
            Key.includesKeyboardBacklight,
            Key.menuBarButton,
            Key.dockIcon,
            Key.doubleKeyShortcutEnabled,
            Key.doubleKeyShortcutKeyCode,
            Key.doubleKeyShortcutKeyName,
            Key.doubleKeyShortcutInterval
        ]
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = legacyDefaults?.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: Key.migratedLegacyBundleDefaults)
    }
}
