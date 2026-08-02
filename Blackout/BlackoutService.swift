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

    private func restoreKeyboardBacklightIfNeeded() {
        keyboardBacklight.restoreAfterBlackoutIfNeeded()
    }
}
