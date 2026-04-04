import Cocoa

struct AccessibilityChecker {
    static var isEnabled: Bool {
        AXIsProcessTrusted()
    }

    static func promptIfNeeded() {
        guard !isEnabled else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
