# dropr

A minimal CLI tool to send files via AirDrop from the macOS terminal.

## Install

```bash
# Build
swiftc main.swift -o airdrop-send -framework AppKit

# Sign (required for AirDrop transfers to work)
codesign -s - -f airdrop-send

# Install
cp airdrop-send /usr/local/bin/
```

Or with Homebrew (optional alias):

```bash
echo 'alias drop="airdrop-send"' >> ~/.zshrc
```

## Usage

```bash
airdrop-send photo.jpg                # single file
airdrop-send report.pdf notes.txt     # multiple files
```

Opens the native macOS AirDrop device picker. Select a device to send.

## Options

```
-h, --help       Show help
-v, --version    Show version
```

## Requirements

- macOS 13+ (Ventura or later)
- Wi-Fi and Bluetooth enabled
- AirDrop enabled on both devices

## License

MIT
