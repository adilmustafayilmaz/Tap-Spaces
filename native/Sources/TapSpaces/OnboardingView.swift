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

            Text("Tap Spaces")
                .font(.system(size: 27, weight: .semibold))
                .padding(.top, 22)

            Text("MacBook'unun etrafındaki masaya vur. Hangi bölgeye vurduğunu duysun, o bölgeye atadığın klavye kısayolunu çalıştırsın.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 14) {
                bullet("square.grid.2x2", "Masa dört bölgeye ayrılır",
                       "Laptopun etrafında sol üst, sağ üst, sol alt, sağ alt.")
                bullet("waveform", "Mikrofon vuruşu tanır",
                       "Her nokta masayı farklı titreştirir; uygulama bu farkı öğrenir.")
                bullet("keyboard", "Kısayol çalışır",
                       "Bölge başına bir tuş kombinasyonu — istediğin gibi değiştirirsin.")
            }
            .padding(.top, 30)

            Text("Kurulum iki izin ve birkaç dakikalık kalibrasyon sürer.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 26)
        }
    }

    private var micStep: some View {
        permissionStep(
            icon: "mic.fill",
            tint: .blue,
            title: "Mikrofon izni",
            body: "Vuruşları duymak için gerekli. Ses hiçbir yere gönderilmez ve kaydedilmez — sadece vuruş anındaki 200 milisaniye analiz edilip atılır.",
            granted: micGranted,
            grantedText: "Mikrofon izni verildi",
            action: "İzin ver"
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
            title: "Erişilebilirlik izni",
            body: "Tuş kombinasyonlarını göndermek için gerekli. ⌃← gibi sistemin kendine ayırdığı kısayolları kaydedebilmek için de şart.\n\nSistem Ayarları açılacak — listeden TapSpaces'i bul ve anahtarı aç.",
            granted: state.accessibilityTrusted,
            grantedText: "Erişilebilirlik izni verildi",
            action: "Ayarları aç"
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

            Text("Son adım: kalibrasyon")
                .font(.system(size: 20, weight: .semibold))

            Text("Uygulama masanı tanımıyor. Her bölgeye birkaç kez vurup öğretmen gerekiyor.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 13) {
                numbered(1, "Bir bölge seç", "Izgarada bir kareye tıkla.")
                numbered(2, "O noktaya 20–30 kez vur", "Sertliği ve tam noktayı biraz değiştir.")
                numbered(3, "Dört bölge için tekrarla", "Dördü de dolmadan doğruluk anlamlı olmaz.")
                numbered(4, "Canlı moda geç", "Artık vurunca kısayol çalışır.")
            }

            Label("Laptop veya masa yer değiştirirse yeniden kalibre et.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
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
                    Button("Geri") { withAnimation { step -= 1 } }
                }
                Button(step == lastStep ? "Kalibrasyona başla" : "Devam") {
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
