import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "App")

@main
struct BrightSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel?
    private let brightnessKeyManager = BrightnessKeyManager()
    // Owned here so migration/restore/re-apply run independent of panel visibility.
    // Without this, display-change handling only exists while the popover is open.
    private let brightnessViewModel = BrightnessViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "BrightSync")
            button.action = #selector(togglePanel)
            button.target = self
        }

        brightnessKeyManager.onBrightnessChanged = {
            NotificationCenter.default.post(name: .brightnessChanged, object: nil)
        }
        brightnessKeyManager.start()
        logger.info("BrightSync launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        brightnessKeyManager.stop()
    }

    @objc private func togglePanel() {
        if let panel, panel.isVisible {
            panel.close()
            self.panel = nil
            return
        }

        guard let button = statusItem.button else { return }
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero

        let contentView = BrightnessPanel(viewModel: brightnessViewModel)
        let hostingView = NSHostingView(rootView: contentView)

        // Use autolayout so the hosting view drives the panel size dynamically
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        // Container view that sizes to the hosting view
        let container = NSView()
        container.addSubview(visualEffect)
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // Initial size estimate, will be corrected by autolayout
        let initialSize = hostingView.fittingSize
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            backing: .buffered,
            defer: false
        )
        panel.contentView = container

        // Observe size changes so the panel resizes when SwiftUI content changes
        panel.sizeObservation = hostingView.observe(\.fittingSize, options: [.new]) { [weak panel] view, _ in
            guard let panel else { return }
            let newSize = view.fittingSize
            guard newSize.width > 0, newSize.height > 0 else { return }
            let frame = panel.frame
            let newOrigin = NSPoint(x: frame.origin.x, y: frame.maxY - newSize.height)
            panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: false)
        }

        let x = buttonFrame.midX - initialSize.width / 2
        let y = buttonFrame.minY - initialSize.height - 4
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)

        // Trigger a re-layout after a tick so the panel picks up the real content size
        DispatchQueue.main.async {
            let realSize = hostingView.fittingSize
            if realSize != initialSize, realSize.width > 0, realSize.height > 0 {
                let newX = buttonFrame.midX - realSize.width / 2
                let newY = buttonFrame.minY - realSize.height - 4
                panel.setFrame(NSRect(x: newX, y: newY, width: realSize.width, height: realSize.height), display: true)
            }
        }

        self.panel = panel
    }
}

/// A borderless, transparent floating panel that dismisses on outside click.
final class FloatingPanel: NSPanel {
    var sizeObservation: NSKeyValueObservation?

    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )
        isFloatingPanel = true
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        close()
    }
}

extension Notification.Name {
    static let brightnessChanged = Notification.Name("brightnessChanged")
}
