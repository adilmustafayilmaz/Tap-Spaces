import AppKit
import Foundation

/// Captures one keyboard shortcut, including combinations macOS reserves for
/// itself.
///
/// A plain `keyDown:` override never sees ⌃← or ⌘⇥ — the WindowServer consumes
/// those for Mission Control and the app switcher before they reach any app.
/// An event tap inserted at the head of the session tap sees them first, and
/// returning `nil` swallows the event so recording a shortcut does not also
/// perform it.
///
/// Requires Accessibility permission. Without it, `CGEvent.tapCreate` returns
/// nil and this falls back to a local monitor, which still handles ordinary
/// combinations like ⌘⇧K.
@MainActor
final class ShortcutCapture {
    static let shared = ShortcutCapture()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var monitor: Any?
    private var handler: ((KeyAction?) -> Void)?

    private(set) var isCapturing = false
    /// True when the current capture is using a local monitor, so
    /// system-reserved combinations will not be recordable.
    private(set) var isDegraded = false

    func begin(_ handler: @escaping (KeyAction?) -> Void) {
        cancel()
        self.handler = handler
        isCapturing = true

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()

        if AXPermission.isTrusted,
           let tap = CGEvent.tapCreate(
               tap: .cgSessionEventTap, place: .headInsertEventTap,
               options: .defaultTap, eventsOfInterest: mask,
               callback: { _, type, event, refcon in
                   guard let refcon else { return Unmanaged.passUnretained(event) }
                   let capture = Unmanaged<ShortcutCapture>.fromOpaque(refcon)
                       .takeUnretainedValue()
                   return MainActor.assumeIsolated {
                       capture.consume(type: type, event: event)
                   }
               },
               userInfo: context)
        {
            self.tap = tap
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isDegraded = false
            return
        }

        // No Accessibility permission — record what we can.
        isDegraded = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .intersection([.command, .option, .control, .shift])
            self.finish(event.keyCode == 53 ? nil
                        : KeyAction(keyCode: event.keyCode, modifiers: mods.rawValue))
            return nil
        }
    }

    private func consume(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables a tap that runs too long or gets interrupted; re-arm
        // rather than silently going deaf.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode == 53 { finish(nil); return nil }          // Escape cancels

        var mods: NSEvent.ModifierFlags = []
        if event.flags.contains(.maskCommand) { mods.insert(.command) }
        if event.flags.contains(.maskAlternate) { mods.insert(.option) }
        if event.flags.contains(.maskControl) { mods.insert(.control) }
        if event.flags.contains(.maskShift) { mods.insert(.shift) }

        finish(KeyAction(keyCode: keyCode, modifiers: mods.rawValue))
        return nil   // swallow, so recording ⌃← does not also switch desktops
    }

    private func finish(_ action: KeyAction?) {
        let handler = self.handler
        cancel()
        handler?(action)
    }

    func cancel() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        source = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        handler = nil
        isCapturing = false
    }
}
