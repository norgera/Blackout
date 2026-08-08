# Blackout

<p align="center"><img src="https://github.com/norgera/Blackout/raw/main/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="120"></p>

<p align="center"><img width="2428" height="694" alt="Blackout" src="https://github.com/user-attachments/assets/6be9bc89-876f-4664-b292-03b00d3f939a" /></p>

Hide your MacBook touch bar natively

## Installation
> Blackout is currently unsigned and unnotarized, so the xattr command removes macOS quarantine after installation.

### Homebrew
```bash
brew install --cask norgera/apps/blackout
xattr -cr /Applications/Blackout.app
```

### Manual

Download the latest version [here](https://github.com/norgera/Blackout/releases/latest/download/Blackout.dmg).

Open `Blackout.dmg` and move Blackout.app to your Applications folder.
Then run: 
```bash
xattr -cr /Applications/Blackout.app
```

## Requirements

- A MacBook Pro with Touch Bar
- Touch Bar configured to **App Controls** with **Show Control Strip** enabled

Blackout currently does not support the **Expanded Control Strip** mode.

## Features

- Black out the Touch Bar while preserving Apple's native controls
- Toggle from the Touch Bar, menu bar, Settings, or a configurable double-press keyboard shortcut
- Optionally require another toggle instead of allowing a Touch Bar tap to restore its controls
- Optional keyboard backlight control with brightness restoration
- Configurable double-press timing and support for any keyboard key, including modifier keys
- Optional Touch Bar button, menu bar button, and Dock presence
- Start automatically at login without opening Settings
- Manually check GitHub for new releases from Settings

## How it works

Blackout uses macOS's native Touch Bar infrastructure to temporarily present a
black Touch Bar. It does not replace or recreate Apple's Control Strip or
application controls.

When Blackout is dismissed, the original Touch Bar is restored.

## Building

Clone the repository and open:

`Blackout.xcodeproj` in Xcode.

Build and run the `Blackout` scheme.

## Contributing

Bug reports and feature suggestions are welcome through GitHub Issues.

Pull requests are also welcome. For larger changes, please open an issue first
so the implementation can be discussed.

## License

[MIT License](LICENSE)
