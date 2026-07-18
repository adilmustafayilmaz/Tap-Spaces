import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// A keyboard shortcut to synthesise when a zone is hit.
struct KeyAction: Codable, Equatable {
    var keyCode: UInt16
    /// Raw value of `NSEvent.ModifierFlags` (device-independent subset).
    var modifiers: UInt

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// Human-readable form, e.g. `⌃→` or `⌘⇥`.
    var display: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + KeyAction.name(for: keyCode)
    }

    private static let named: [UInt16: String] = [
        UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Space): "Space", UInt16(kVK_Tab): "⇥",
        UInt16(kVK_Return): "↩", UInt16(kVK_Escape): "⎋",
        UInt16(kVK_Delete): "⌫", UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_Home): "↖", UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞", UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]

    /// Resolve a key code to its label using the active keyboard layout, so a
    /// Turkish Q layout shows the character actually printed on the key.
    static func name(for keyCode: UInt16) -> String {
        if let n = named[keyCode] { return n }

        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }

        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { buf -> OSStatus in
            guard let layout = buf.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(-1)
            }
            return UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    /// Post the shortcut to the system as if it were typed.
    func post() {
        let source = CGEventSource(stateID: .combinedSessionState)
        var cgFlags: CGEventFlags = []
        if flags.contains(.command) { cgFlags.insert(.maskCommand) }
        if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
        if flags.contains(.control) { cgFlags.insert(.maskControl) }
        if flags.contains(.shift) { cgFlags.insert(.maskShift) }

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = cgFlags
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = cgFlags
        up?.post(tap: .cghidEventTap)
    }
}

enum AXPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Ask macOS to show the "grant access" prompt for this app.
    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
}
