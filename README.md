# BrightSync

A lightweight macOS menu bar app that controls and syncs brightness across multiple Apple Studio Displays.

Built natively in Swift with zero dependencies.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Per-display brightness sliders** for every connected Apple Studio Display
- **Sync mode** — toggle to keep all displays at the same brightness level
- **F1/F2 key sync** — when you press brightness keys, all synced displays follow automatically
- **Auto-detect displays** — instantly updates when displays are connected or disconnected
- **Remembers settings** — persists brightness levels and sync preference across launches
- **Liquid glass UI** — native macOS vibrancy with frosted glass cards

## How It Works

BrightSync uses Apple's private `DisplayServices` framework (the same API macOS uses internally) to read and write brightness on Apple displays. A background monitor polls for brightness changes at 100ms intervals, so when you press F1/F2 on your keyboard, BrightSync detects the change on the primary display and instantly syncs all other displays to match.

**Supported displays:**
- Apple Studio Display
- Apple Pro Display XDR
- Built-in MacBook/iMac displays

Third-party monitors are automatically filtered out (they use DDC/CI, which requires a different protocol).

## Installation

### From source

**Requirements:** macOS 14+, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/MySethPorter/brightsync.git
cd brightsync
xcodegen generate
xcodebuild -project BrightSync.xcodeproj -scheme BrightSync -configuration Release build
```

Copy the built app to Applications:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/BrightSync-*/Build/Products/Release/BrightSync.app /Applications/
```

## Usage

1. Launch BrightSync — a sun icon appears in your menu bar
2. Click the icon to see brightness sliders for each connected display
3. Drag sliders to adjust individual display brightness
4. Toggle **Sync All Displays** to lock all displays to the same brightness
5. With sync enabled, pressing F1/F2 adjusts all displays simultaneously

## Architecture

```
BrightSync/
├── BrightSyncApp.swift            # Entry point, NSStatusItem, floating panel
├── Services/
│   ├── DisplayService.swift       # Private DisplayServices framework (dlopen)
│   ├── DisplayMonitor.swift       # Display enumeration + connect/disconnect
│   └── BrightnessKeyManager.swift # F1/F2 brightness change detection + sync
├── Models/
│   └── DisplayInfo.swift          # Display model
├── ViewModels/
│   └── BrightnessViewModel.swift  # Sync logic, persistence
└── Views/
    ├── BrightnessPanel.swift      # Main popover layout
    ├── DisplaySliderCard.swift    # Per-display glass card
    └── GlassSliderStyle.swift     # Custom slider control
```

**Key technical details:**
- Uses `dlopen` to load `DisplayServicesGetBrightness` / `DisplayServicesSetBrightness` from the private framework
- `NSVisualEffectView` with `.popover` material for native macOS vibrancy
- Custom `NSPanel` (borderless, transparent) for the floating popover
- 300ms debounce on display connect/disconnect (NSScreen can return stale data)
- Sandbox disabled (required for `dlopen` of private frameworks)

## Privacy & Permissions

- **No network access** — BrightSync never connects to the internet
- **No Accessibility permission needed** — brightness control uses DisplayServices, not event taps
- **No data collection** — all settings stored locally in UserDefaults

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

Built by [Seth Porter](https://github.com/MySethPorter). Brightness control approach inspired by [Lockpaw](https://github.com/sorkila/lockpaw).
