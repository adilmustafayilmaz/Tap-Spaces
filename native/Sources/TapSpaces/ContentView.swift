import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.hasOnboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.hasOnboarded)
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            board
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            statusStrip
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Divider()

            settings
        }
        .frame(width: 520, height: 680)
        .onAppear { state.refreshAccessibility() }
    }

    // ==================================================================
    // Board
    // ==================================================================
    private var board: some View {
        VStack(spacing: 10) {
            Picker("", selection: $state.mode) {
                Text("Kalibrasyon").tag(Mode.calibrate)
                Text("Canlı").tag(Mode.live)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ZStack {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        zoneTile(.topLeft)
                        zoneTile(.topRight)
                    }
                    GridRow {
                        zoneTile(.bottomLeft)
                        zoneTile(.bottomRight)
                    }
                }
                laptop
            }
            .frame(height: 226)

            Text(state.mode == .calibrate
                 ? "Bir bölge seç, sonra masanın o noktasına vur. Bölge başına 20–30 vuruş."
                 : "Masaya vur — tahmin edilen bölge yanar ve kısayolu çalışır.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func zoneTile(_ zone: Zone) -> some View {
        let hit = state.lastZone == zone
        let armed = state.mode == .calibrate && state.armedZone == zone
        let score = state.scores[zone] ?? 0
        let count = state.counts[zone] ?? 0
        let empty = count == 0

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hit ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    armed ? Color.accentColor
                          : hit ? Color.accentColor.opacity(0.7)
                          : empty ? Color.orange.opacity(0.55)
                          : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: armed || hit ? 2 : 1,
                                       dash: empty && !armed ? [4, 3] : []))

            VStack(spacing: 3) {
                Text(zone.title).font(.system(size: 13, weight: .semibold))

                if state.mode == .live && state.isReady {
                    Text("%\(Int(score * 100))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if empty {
                    Text("kalibre değil")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                }

                if let action = state.bindings[zone] {
                    Text(action.display)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Capsule().fill(.primary.opacity(0.08)))
                        .padding(.top, 1)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(7)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            state.armedZone = zone
            state.mode = .calibrate
        }
        .animation(.easeOut(duration: 0.16), value: hit)
    }

    private var laptop: some View {
        VStack(spacing: 1.5) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1.5))
                .overlay(Image(systemName: "laptopcomputer")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary))
                .frame(width: 74, height: 46)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 92, height: 4)
        }
        .allowsHitTesting(false)
    }

    // ==================================================================
    private var statusStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state.micDenied ? .red : .green)
                .frame(width: 6, height: 6)
            Text(state.micDenied ? "mikrofon izni yok" : "dinleniyor")
                .font(.caption)
                .foregroundStyle(.secondary)

            LevelMeter(level: state.level)
                .frame(width: 72, height: 4)

            Spacer()

            if let acc = state.accuracy {
                Text("doğruluk %\(Int(acc * 100))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(acc > 0.8 ? .green : acc > 0.6 ? .orange : .red)
            }
            Text("\(state.totalSamples) örnek")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // ==================================================================
    // Settings
    // ==================================================================
    private var settings: some View {
        Form {
            if !state.accessibilityTrusted {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Erişilebilirlik izni gerekli")
                                .font(.system(size: 12.5, weight: .medium))
                            Text("İzin olmadan tuşlar gönderilemez ve ⌃← gibi sistem kısayolları kaydedilemez.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button("Ayarları aç") { AXPermission.openSettings() }
                                Button("Yeniden denetle") { state.refreshAccessibility() }
                            }
                            .controlSize(.small)
                            .padding(.top, 2)
                        }
                    }
                }
            }

            Section("Kısayollar") {
                ForEach(Zone.allCases) { zone in
                    HStack {
                        Text(zone.title)
                        Spacer()
                        KeyRecorder(action: Binding(
                            get: { state.bindings[zone] },
                            set: { state.bindings[zone] = $0; state.save() }
                        ))
                        .frame(width: 128, height: 24)

                        Button {
                            state.bindings[zone] = nil
                            state.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                        .disabled(state.bindings[zone] == nil)
                        .opacity(state.bindings[zone] == nil ? 0.25 : 1)
                        .help("Bu bölgenin kısayolunu kaldır")
                    }
                }

                HStack {
                    Button("Varsayılanlara dön") { state.restoreDefaultBindings() }
                        .disabled(state.usingDefaultBindings)
                    Button("Tümünü kaldır") { state.clearAllBindings() }
                        .disabled(state.bindings.isEmpty)
                    Spacer()
                }
                .controlSize(.small)
            }

            Section("Davranış") {
                Toggle("Kısayolları çalıştır", isOn: $state.actionsEnabled)
                    .onChange(of: state.actionsEnabled) { _, on in
                        if on && !AXPermission.isTrusted { AXPermission.requestAccess() }
                        state.refreshAccessibility()
                        state.save()
                    }

                HStack {
                    Toggle("Bildirim göster", isOn: $state.showToast)
                        .onChange(of: state.showToast) { _, _ in state.save() }
                    Spacer()
                    Button("Dene") {
                        ToastPresenter.shared.show(
                            zone: state.armedZone.title,
                            shortcut: state.bindings[state.armedZone]?.display ?? "⌃←")
                    }
                    .controlSize(.small)
                    .disabled(!state.showToast)
                }

                LabeledContent("Hassasiyet") {
                    VStack(alignment: .leading, spacing: 1) {
                        Slider(value: $state.sensitivity, in: 0...100) { _ in state.save() }
                        HStack {
                            Text("sert").font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                            Text("hafif").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 190)
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        Slider(value: $state.minConfidence, in: 0.25...0.95) { _ in state.save() }
                            .frame(width: 150)
                        Text("%\(Int(state.minConfidence * 100))")
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                } label: {
                    Text("En az güven")
                    Text("Bunun altındaki tahminler kısayolu tetiklemez.")
                }
            }

            Section("Kalibrasyon") {
                HStack {
                    Button("\(state.armedZone.title) bölgesini sil") { state.clear(state.armedZone) }
                        .disabled((state.counts[state.armedZone] ?? 0) == 0)
                    Button("Tümünü sil", role: .destructive) { state.clear(nil) }
                        .disabled(state.totalSamples == 0)
                    Spacer()
                }
                .controlSize(.small)

                Button("Tanıtımı tekrar göster") {
                    state.hasOnboarded = false
                    state.save()
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
    }
}

/// Peak-holding level meter — a bare value bar flickers too fast to read.
struct LevelMeter: View {
    let level: Float
    @State private var peak: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(nsColor: .separatorColor))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * peak)
            }
        }
        .onChange(of: level) { _, new in
            let scaled = min(1, Double(new) * 9)
            peak = scaled > peak ? scaled : peak * 0.82 + scaled * 0.18
        }
    }
}
