# BrightSync

macOS menu bar app to control and sync brightness across multiple Apple Studio Displays.

## Quick reference

- **Bundle ID:** `com.eriknielsen.brightsync`
- **Requires:** macOS 14+, Xcode 16+, XcodeGen
- **Dependencies:** None (no SPM packages)
- **Permissions:** Accessibility (for F1/F2 key interception)

## Build

```bash
xcodegen generate
xcodebuild -project BrightSync.xcodeproj -scheme BrightSync -configuration Debug build
```

After rebuilding, reset TCC if needed (binary signature changes invalidate Accessibility permission):
```bash
tccutil reset Accessibility com.eriknielsen.brightsync
```

## Install

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/BrightSync-*/Build/Products/Debug/BrightSync.app /Applications/
```

## Architecture

- **DisplayService** — dlopen of private DisplayServices framework for brightness get/set (ported from Lockpaw)
- **DisplayMonitor** — enumerates displays via CGGetOnlineDisplayList, watches for connect/disconnect with 300ms debounce
- **BrightnessKeyManager** — CGEventTap on dedicated background thread intercepting F1/F2 system-defined events (NX_KEYTYPE_BRIGHTNESS_UP/DOWN)
- **BrightnessViewModel** — sync logic, UserDefaults persistence, orchestrates DisplayService calls
- **BrightnessPanel** — MenuBarExtra(.window) popover with liquid glass UI
- **DisplaySliderCard** — per-display dark glass card with custom thick-track slider
- **GlassSlider** — custom slider matching macOS Control Center aesthetic
- **AccessibilityChecker** — AXIsProcessTrusted prompt (ported from Lockpaw)

## Key decisions

- Uses `DisplayServicesGetBrightness` / `DisplayServicesSetBrightness` private API (same as Lockpaw)
- Only shows displays where getBrightness succeeds (filters out non-Apple monitors)
- Sandbox OFF required for dlopen of private framework
- `.window` MenuBarExtra style required for interactive Slider controls
- 300ms screen-change debounce (NSScreen.screens can return stale data at notification time)
- F1/F2 interception uses `.defaultTap` (not `.listenOnly`) to consume events and prevent double-handling
- Brightness step = 1/16 per key press, matching macOS native behavior
- Dark color scheme forced (`.preferredColorScheme(.dark)`) for Control Center aesthetic
