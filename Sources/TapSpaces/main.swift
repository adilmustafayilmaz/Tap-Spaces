import AppKit
import Combine
import SwiftUI

/// Menu bar app. The activation policy stays `.accessory` for the whole
/// lifetime, so there is never a Dock icon or an app-switcher entry —
/// everything is reached from the status item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let state = AppState()
    private let updater = UpdateChecker()
    private var observer: NSObjectProtocol?
    private var langSub: AnyCancellable?
    private var updateSub: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = AppDelegate.menuBarIcon()
        statusItem.button?.toolTip = "Tap Spaces"
        rebuildMenu()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Tap Spaces"
        // The content draws its own headers; a title string on top of them
        // reads as an overlap.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: RootView().environmentObject(state))
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Onboarding explains the microphone before asking for it. Starting the
        // detector here would fire the system prompt on launch, ahead of any
        // explanation — so a first-run app waits for the user to get there.
        if state.hasOnboarded { state.start() }
        showWindow()

        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.state.refreshAccessibility() }
        }

        // SwiftUI re-renders on its own when the language changes; the menu
        // bar is AppKit and has to be rebuilt by hand. The main-queue hop
        // runs after AppState's didSet has already re-pointed L10n.
        langSub = state.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }

        updater.start()
        updateSub = updater.$availableVersion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
    }

    // ------------------------------------------------------------------
    // Menu bar
    // ------------------------------------------------------------------

    /// The app icon's mark, redrawn as a menu bar template: three outlined
    /// zones and one lit. Marked as a template so macOS tints it for light and
    /// dark menu bars automatically.
    private static func menuBarIcon() -> NSImage {
        let side: CGFloat = 16
        let image = NSImage(size: NSSize(width: side, height: side),
                            flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            let grid: CGFloat = 13
            let gap: CGFloat = 1.6
            let cell = (grid - gap) / 2
            let originX = (side - grid) / 2, originY = (side - grid) / 2
            let radius = cell * 0.28

            func rect(_ col: Int, _ row: Int) -> CGRect {
                CGRect(x: originX + CGFloat(col) * (cell + gap),
                       y: originY + CGFloat(row) * (cell + gap),
                       width: cell, height: cell)
            }

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.3)
            for (col, row) in [(1, 0), (0, 1), (1, 1)] {
                ctx.addPath(CGPath(roundedRect: rect(col, row).insetBy(dx: 0.65, dy: 0.65),
                                   cornerWidth: radius, cornerHeight: radius, transform: nil))
                ctx.strokePath()
            }
            ctx.addPath(CGPath(roundedRect: rect(0, 0), cornerWidth: radius,
                               cornerHeight: radius, transform: nil))
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if let version = updater.availableVersion {
            menu.addItem(withTitle: L("menu.updateAvailable", version),
                         action: #selector(openReleases), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: L("menu.settings"),
                     action: #selector(showWindow), keyEquivalent: ",").target = self

        let toggle = menu.addItem(withTitle: L("toggle.runShortcuts"),
                                  action: #selector(toggleActions), keyEquivalent: "")
        toggle.target = self
        toggle.state = state.actionsEnabled ? .on : .off

        let toast = menu.addItem(withTitle: L("toggle.showToast"),
                                 action: #selector(toggleToast), keyEquivalent: "")
        toast.target = self
        toast.state = state.showToast ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.quit"),
                     action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    private func statusLine() -> String {
        if state.micDenied { return L("status.micDenied") }
        if !state.isReady { return L("menu.status.needCalibration") }
        if !state.actionsEnabled { return L("menu.status.shortcutsOff") }
        if !state.accessibilityTrusted { return L("ax.required") }
        if let acc = state.accuracy {
            return L("menu.status.activeAccuracy", Int(acc * 100))
        }
        return L("menu.status.active")
    }

    // ------------------------------------------------------------------
    // Window
    // ------------------------------------------------------------------

    /// `NSWindow.center()` picks a screen on its own, which on a multi-display
    /// setup can drop the window onto a monitor the user is not looking at —
    /// or partly off the top edge when the displays differ in height.
    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        frame.origin.y = min(frame.origin.y, visible.maxY - frame.height)
        frame.origin.y = max(frame.origin.y, visible.minY)
        window.setFrame(frame, display: true)
    }

    @objc private func showWindow() {
        if !window.isVisible { centerOnActiveScreen() }
        window.makeKeyAndOrderFront(nil)
        // An accessory app has to ask explicitly; without this the window can
        // open behind whatever the user was working in.
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        state.save()
    }

    // ------------------------------------------------------------------
    @objc private func toggleActions() {
        state.actionsEnabled.toggle()
        if state.actionsEnabled && !AXPermission.isTrusted { AXPermission.requestAccess() }
        state.save()
        rebuildMenu()
    }

    @objc private func toggleToast() {
        state.showToast.toggle()
        state.save()
        rebuildMenu()
    }

    @objc private func openReleases() {
        UpdateChecker.open()
    }

    @objc private func quit() {
        state.stop()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Reopening from the Finder (or a second launch) surfaces the window
    /// again — otherwise the app looks like it did nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Refresh the status line and checkmarks each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        state.refreshAccessibility()
        rebuildMenu()
    }
}

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run())
}

// Headless probe for the update check: fetches the latest release tag,
// compares it with the bundle version and prints the verdict.
if CommandLine.arguments.contains("--check-update") {
    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    let api = URL(string: "https://api.github.com/repos/adilmustafayilmaz/Tap-Spaces/releases/latest")!
    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: api) { data, _, error in
        defer { semaphore.signal() }
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String else {
            print("fetch failed: \(error?.localizedDescription ?? "bad response")")
            return
        }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        print("current \(current), latest \(latest) → "
              + (UpdateChecker.isNewer(latest, than: current) ? "UPDATE AVAILABLE" : "up to date"))
    }.resume()
    semaphore.wait()
    exit(0)
}

// Renders one toast and quits — lets the notification be inspected without
// having to trigger a real tap.
if CommandLine.arguments.contains("--toast-demo") {
    forcePlainToast = CommandLine.arguments.contains("--toast-demo-plain")
    let demo = NSApplication.shared
    demo.setActivationPolicy(.accessory)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        MainActor.assumeIsolated {
            ToastPresenter.shared.show(zone: Zone.bottomLeft.title, shortcut: "⌃←", duration: 8)
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { NSApp.terminate(nil) }
    demo.run()
}

// Top-level code in main.swift runs on the main thread but is not statically
// main-actor isolated, so the delegate has to be constructed inside an
// explicitly isolated block.
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
