import AVFoundation
import SwiftUI

/// First-run introduction: what the app does, the two permissions it needs, and
/// how calibration works. Permissions are requested inline so the user never
/// has to go hunting for them.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    private let lastStep = 3

    var body: some View {
        VStack(spacing: 0) {
            // Centres a short step vertically but still scrolls a long one,
            // instead of pinning everything to the top and leaving dead space.
            GeometryReader { geo in
                ScrollView {
                    content
                        .padding(.horizontal, 44)
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity,
                               minHeight: geo.size.height,
                               alignment: .center)
                }
            }
            footer
        }
        .frame(width: 520, height: 600)
        .background(.background)
        // Grant the permission in System Settings and the checkmark should
        // appear here without the user having to click anything.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard step == 2 else { return }
            state.refreshAccessibility()
        }
    }

    // ------------------------------------------------------------------
    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: micStep
        case 2: accessibilityStep
        default: calibrationStep
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            ZoneGlyph(side: 76)

            HStack(spacing: 9) {
                Text("Tap Spaces")
                    .font(.system(size: 27, weight: .semibold))
                Text(localised: "onboarding.beta")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.orange.opacity(0.16)))
                    .offset(y: 2)
            }
            .padding(.top, 22)

            Text(localised: "welcome.tagline")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 14) {
                bullet("square.grid.2x2", L("welcome.zones.title"), L("welcome.zones.detail"))
                bullet("waveform", L("welcome.mic.title"), L("welcome.mic.detail"))
                bullet("keyboard", L("welcome.keys.title"), L("welcome.keys.detail"))
            }
            .padding(.top, 30)

            VStack(spacing: 5) {
                Text(localised: "welcome.footnote1")
                Text(localised: "welcome.footnote2")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 24)
        }
    }

    private var micStep: some View {
        permissionStep(
            icon: "mic.fill",
            tint: .blue,
            title: L("mic.title"),
            body: L("mic.body"),
            granted: micGranted,
            grantedText: L("mic.granted"),
            action: L("mic.action")
        ) {
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                Task { @MainActor in
                    micGranted = ok
                    if ok { state.start() }
                }
            }
        }
    }

    private var accessibilityStep: some View {
        permissionStep(
            icon: "hand.raised.fill",
            tint: .orange,
            title: L("axStep.title"),
            body: L("axStep.body"),
            granted: state.accessibilityTrusted,
            grantedText: L("axStep.granted"),
            action: L("axStep.action")
        ) {
            AXPermission.requestAccess()
            AXPermission.openSettings()
        }
    }

    private var calibrationStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 46))
                .foregroundStyle(.tint)
                .padding(.bottom, 2)

            Text(localised: "calStep.title")
                .font(.system(size: 20, weight: .semibold))

            Text(localised: "calStep.body")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 13) {
                numbered(1, L("calStep.1.title"), L("calStep.1.detail"))
                numbered(2, L("calStep.2.title"), L("calStep.2.detail"))
                numbered(3, L("calStep.3.title"), L("calStep.3.detail"))
                numbered(4, L("calStep.4.title"), L("calStep.4.detail"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(L("calStep.note.fewer"), systemImage: "chart.bar.fill")
                Label(L("calStep.note.single"), systemImage: "exclamationmark.circle")
                Label(L("calStep.note.moved"), systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ------------------------------------------------------------------
    private func permissionStep(icon: String, tint: Color, title: String, body: String,
                                granted: Bool, grantedText: String, action: String,
                                perform: @escaping () -> Void) -> some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(tint)

            Text(title).font(.system(size: 20, weight: .semibold))

            Text(body)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if granted {
                Label(grantedText, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Button(action, action: perform)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func numbered(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ------------------------------------------------------------------
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                HStack(spacing: 6) {
                    ForEach(0...lastStep, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.28))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                if step > 0 {
                    Button(L("onboarding.back")) { withAnimation { step -= 1 } }
                }
                Button(step == lastStep ? L("onboarding.start") : L("onboarding.continue")) {
                    if step == lastStep {
                        state.hasOnboarded = true
                        state.mode = .calibrate
                        // Covers the case where the user skipped past the
                        // microphone step without granting — start() is a no-op
                        // if the detector is already running.
                        state.start()
                        state.save()
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.bar)
    }
}

/// The app mark, reused in onboarding and the about box.
///
/// Laid out with nested stacks at an explicit size rather than a
/// `GeometryReader`: the reader reports its size back to the parent lazily,
/// which let the title creep up underneath the glyph.
struct ZoneGlyph: View {
    var side: CGFloat = 84
    var lit: Zone = .bottomLeft

    var body: some View {
        let gap = side * 0.09
        let cell = (side - gap) / 2

        VStack(spacing: gap) {
            HStack(spacing: gap) {
                square(.topLeft, cell)
                square(.topRight, cell)
            }
            HStack(spacing: gap) {
                square(.bottomLeft, cell)
                square(.bottomRight, cell)
            }
        }
        .frame(width: side, height: side)
    }

    private func square(_ zone: Zone, _ cell: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cell * 0.26, style: .continuous)
            .fill(zone == lit ? AnyShapeStyle(Color.accentColor)
                              : AnyShapeStyle(Color.accentColor.opacity(0.20)))
            .frame(width: cell, height: cell)
    }
}
