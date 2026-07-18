import AppKit
import SwiftUI

/// Click, then press a combination. Capture goes through `ShortcutCapture` so
/// system-reserved combinations like ⌃← are recordable too.
struct KeyRecorder: NSViewRepresentable {
    @Binding var action: KeyAction?
    var placeholder: String = "Kısayol ata"

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = { action = $0 }
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.action = action
        view.placeholder = placeholder
        view.needsDisplay = true
    }

    final class RecorderView: NSView {
        var action: KeyAction?
        var placeholder = "Kısayol ata"
        var onCapture: ((KeyAction?) -> Void)?

        private var recording = false { didSet { needsDisplay = true } }

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            if recording {
                MainActor.assumeIsolated { ShortcutCapture.shared.cancel() }
                recording = false
                return
            }
            recording = true
            MainActor.assumeIsolated {
                ShortcutCapture.shared.begin { [weak self] captured in
                    guard let self else { return }
                    self.recording = false
                    guard let captured else { return }   // Escape cancelled
                    self.action = captured
                    self.onCapture?(captured)
                    self.needsDisplay = true
                }
            }
        }

        override func draw(_ dirtyRect: NSRect) {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                    xRadius: 6, yRadius: 6)
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                       : NSColor.textBackgroundColor).setFill()
            path.fill()
            (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = recording ? 2 : 1
            path.stroke()

            let text = recording ? "tuşlara bas…" : (action?.display ?? placeholder)
            let color: NSColor = recording ? .controlAccentColor
                : (action == nil ? .tertiaryLabelColor : .labelColor)
            let str = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: action == nil ? .regular : .medium),
                .foregroundColor: color,
            ])
            let size = str.size()
            str.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                 y: (bounds.height - size.height) / 2))
        }
    }
}
