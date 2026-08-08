import Foundation

final class BlackoutService {
    private let touchBar = TouchBarController.shared
    private let keyboardBacklight = KeyboardBacklightController.shared
    private let preferences = PreferencesService.shared

    func configureTouchBarActions() {
        touchBar.toggleHandler = { [weak self] in
            self?.toggle()
        }
        touchBar.blackoutDismissedHandler = { [weak self] in
            self?.restoreKeyboardBacklightIfNeeded()
        }
    }

    func toggle() {
        let wasBlackoutActive = touchBar.isBlackoutActive
        touchBar.toggle()
        if !wasBlackoutActive,
           touchBar.isBlackoutActive,
           preferences.includesKeyboardBacklight {
            _ = keyboardBacklight.turnOffForBlackout()
        }
    }

    func installTouchBarButton() {
        _ = touchBar.installTouchBarToggle()
    }

    func uninstallTouchBarButton() {
        touchBar.uninstallTouchBarToggle()
    }

    func applyKeyboardBacklightPreference() {
        guard touchBar.isBlackoutActive else { return }

        if preferences.includesKeyboardBacklight {
            _ = keyboardBacklight.turnOffForBlackout()
        } else {
            keyboardBacklight.restoreAfterBlackoutIfNeeded()
        }
    }

    func restore() {
        if touchBar.isBlackoutActive {
            touchBar.dismissBlackoutIfNeeded()
        } else {
            keyboardBacklight.restoreAfterBlackoutIfNeeded()
        }
    }

    func recoverInterruptedKeyboardBacklightIfNeeded() {
        keyboardBacklight.restoreAfterBlackoutIfNeeded()
    }

    private func restoreKeyboardBacklightIfNeeded() {
        keyboardBacklight.restoreAfterBlackoutIfNeeded()
    }
}
