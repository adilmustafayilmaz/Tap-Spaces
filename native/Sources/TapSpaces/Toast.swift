import AppKit
import SwiftUI

@MainActor
final class ToastModel: ObservableObject {
    @Published var zone: String = ""
    @Published var shortcut: String = ""
    @Published var visible: Bool = false
}

struct ToastView: View {
    @ObservedObject var model: ToastModel

    var body: some View {
        VStack {
            Spacer()
            content
                .opacity(model.visible ? 1 : 0)
                .offset(y: model.visible ? 0 : 14)
                .scaleEffect(model.visible ? 1 : 0.96)
                .animation(.spring(response: 0.34, dampingFraction: 0.78), value: model.visible)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        GlassContainer {
            HStack(spacing: 9) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(model.zone)
                    .font(.system(size: 13.5, weight: .medium))

                Text(model.shortcut)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule().fill(.primary.opacity(0.09))
                    )
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .modifier(GlassCapsule())
        }
    }
}

/// `glassEffect` is meant to be rendered inside a container — without one the
/// lensing spills outside the capsule and reads as a dark smear.
private struct GlassContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
    }
}

/// Set by `--toast-demo-plain` to compare the glass path against the fallback.
nonisolated(unsafe) var forcePlainToast = false

/// Liquid Glass where the OS provides it, a material-backed capsule elsewhere.
private struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !forcePlainToast {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.28), radius: 16, y: 6)
        }
    }
}

/// Bottom-of-screen toast shown when a tap fires a shortcut.
///
/// The panel must never take focus: the keystroke was just posted to whatever
/// app is frontmost, and activating here would steal it back.
@MainActor
final class ToastPresenter {
    static let shared = ToastPresenter()

    private let model = ToastModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    private let size = NSSize(width: 460, height: 110)

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Follow the user across spaces and sit above full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                    .fullScreenAuxiliary, .ignoresCycle]

        let host = NSHostingView(rootView: ToastView(model: model))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        return panel
    }

    func show(zone: String, shortcut: String, duration: TimeInterval = 1.6) {
        let panel = self.panel ?? {
            let p = makePanel()
            self.panel = p
            return p
        }()

        model.zone = zone
        model.shortcut = shortcut

        // Re-place every time so the toast follows the active display.
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            panel.setFrame(NSRect(x: visible.midX - size.width / 2,
                                  y: visible.minY + 32,
                                  width: size.width, height: size.height),
                           display: false)
        }

        // orderFrontRegardless keeps a non-activating panel visible without
        // making the app active.
        panel.orderFrontRegardless()
        model.visible = true

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.model.visible = false
            // Let the exit animation finish before pulling the panel.
            let close = DispatchWorkItem { [weak self] in
                guard let self, self.model.visible == false else { return }
                self.panel?.orderOut(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: close)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}
