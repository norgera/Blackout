import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            settingsCard(
                title: "Blackout",
                actionTitle: "Toggle blackout",
                action: model.toggleBlackout
            ) {
                settingToggle(
                    title: "Show touch bar button",
                    description: nil,
                    value: binding(
                        get: { model.isTouchBarButtonEnabled },
                        set: model.setTouchBarButtonEnabled
                    )
                )
                settingToggle(
                    title: "Tap to restore",
                    description: "Touch the black bar to restore its controls. Turn this off to require Settings, the menu bar, or your shortcut.",
                    value: binding(
                        get: { model.isTouchBarTapToRestoreEnabled },
                        set: model.setTouchBarTapToRestoreEnabled
                    )
                )
                settingToggle(
                    title: "Include keyboard backlight",
                    description: "Turns off the keyboard backlight with the Touch Bar, then restores its previous brightness. Manual changes are preserved.",
                    value: binding(
                        get: { model.includesKeyboardBacklight },
                        set: model.setIncludesKeyboardBacklight
                    )
                )
            }
            settingsCard(title: "Double-press shortcut") {
                settingToggle(
                    title: "Enable shortcut",
                    description: "Double-press a key anywhere to toggle blackout. “Press window” is the allowed delay. Requires Input Monitoring.",
                    value: binding(
                        get: { model.isDoubleKeyShortcutEnabled },
                        set: model.setDoubleKeyShortcutEnabled
                    )
                )
                if let status = model.shortcutStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Trigger key")
                    Spacer()
                    Button(model.shortcutButtonTitle) {
                        model.beginRecordingShortcutKey()
                    }
                    .disabled(model.isRecordingShortcutKey)
                }
                HStack(spacing: 12) {
                    Text("Press window")
                    Slider(
                        value: binding(
                            get: { model.shortcutInterval },
                            set: model.setShortcutInterval
                        ),
                        in: 0.15...1,
                        step: 0.05
                    )
                    Text(model.shortcutIntervalTitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 58, alignment: .trailing)
                }
            }
            settingsCard(title: "Application") {
                settingToggle(
                    title: "Show menu bar button",
                    description: nil,
                    value: binding(
                        get: { model.isMenuBarButtonEnabled },
                        set: model.setMenuBarButtonEnabled
                    )
                )
                settingToggle(
                    title: "Show app in dock",
                    description: nil,
                    value: binding(
                        get: { model.isDockIconEnabled },
                        set: model.setDockIconEnabled
                    )
                )
                settingToggle(
                    title: "Start at login",
                    description: nil,
                    value: binding(
                        get: { model.isLaunchAtLoginEnabled },
                        set: model.setLaunchAtLoginEnabled
                    )
                )
                .disabled(!model.isLaunchAtLoginAvailable)
            }
            HStack {
                Spacer()
                Button("Quit Blackout") {
                    model.quit()
                }
            }
            .padding(.trailing, 4)
            .padding(.bottom, 4)
        }
        .padding(16)
        .frame(minWidth: 440, minHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Blackout")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(model.versionTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    if let updateURL = model.availableUpdateURL {
                        Button("View update") {
                            NSWorkspace.shared.open(updateURL)
                        }
                        .fixedSize()
                    }
                    Button(
                        model.isCheckingForUpdates ? "Checking…" : "Check for updates"
                    ) {
                        model.checkForUpdates()
                    }
                    .disabled(model.isCheckingForUpdates)
                    .fixedSize()
                }
                if let updateStatus = model.updateStatus {
                    Text(updateStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func settingToggle(
        title: String,
        description: String?,
        value: Binding<Bool>
    ) -> some View {
        HStack(spacing: 9) {
            Text(title)
            if let description {
                TooltipInfoIcon(text: description)
                    .frame(width: 20, height: 20)
            }
            Spacer()
            Toggle("", isOn: value)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
                .fixedSize()
        }
        .frame(minHeight: 28)
    }

    private func settingsCard<Content: View>(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                }
            }
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.65), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}

private struct TooltipInfoIcon: View {
    let text: String
    @State private var isHovered = false
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
            .overlay(
                Group {
                    if isHovered {
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 240, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(NSColor.windowBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 5, y: 2)
                            .offset(y: -24)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .bottom
            )
            .zIndex(isHovered ? 10 : 0)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
