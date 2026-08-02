# Blackout

<p align="center"><img src="https://github.com/norgera/Blackout/raw/main/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="120"></p>

<p align="center"><img width="2428" height="694" alt="Blackout" src="https://github.com/user-attachments/assets/6be9bc89-876f-4664-b292-03b00d3f939a" /></p>

Hide your MacBook touch bar natively

## Installation

### Manual

Download the latest version of Blackout from the [Releases](../../releases/latest) page.

Open `Blackout.dmg` and move Blackout.app to your Applications folder.

## Requirements

- A MacBook Pro with Touch Bar
- Touch Bar configured to **App Controls** with **Show Control Strip** enabled

Blackout currently does not support the **Expanded Control Strip** mode.

### Homebrew

Coming soon.

## Features

- Black out the Touch Bar while preserving Apple's native controls
- Toggle from the Touch Bar or menu bar
- Optional keyboard backlight control with brightness restoration
- Launch at login

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
