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
                Text(localised: "mode.calibrate").tag(Mode.calibrate)
                Text(localised: "mode.live").tag(Mode.live)
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
                 ? L("board.hint.calibrate")
                 : L("board.hint.live"))
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

        let showFill = state.mode == .live && state.canDiscriminate

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))

            // The score as a level, filling from the bottom, so the four zones
            // read as competing bars at a glance without parsing the numbers.
            if showFill {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor.opacity(hit ? 0.42 : 0.26))
                        .frame(height: geo.size.height * score)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(.easeOut(duration: 0.28), value: score)
            } else if hit {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.22))
            }

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
                    Text(L("confidence.value", Int(score * 100)))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if empty {
                    Text(localised: "tile.uncalibrated")
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
                    if zone.isLeft {
                        sampleBadge(count)
                        Spacer()
                    } else {
                        Spacer()
                        sampleBadge(count)
                    }
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

    private var sensitivityLabel: String {
        switch state.sensitivity {
        case ..<25: return L("sensitivity.veryLow")
        case ..<45: return L("sensitivity.low")
        case ..<70: return L("sensitivity.medium")
        case ..<88: return L("sensitivity.high")
        default: return L("sensitivity.veryHigh")
        }
    }

    private func sampleBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(.tertiary)
            .monospacedDigit()
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
            Text(state.micDenied ? L("status.micDenied") : L("status.listening"))
                .font(.caption)
                .foregroundStyle(.secondary)

            LevelMeter(level: state.level)
                .frame(width: 72, height: 4)

            Spacer()

            if state.isReady && !state.canDiscriminate {
                // A single trained zone always scores 100%; showing that as
                // accuracy would be a lie.
                Text(localised: "status.singleZone")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else if let acc = state.accuracy {
                Text(L("status.accuracy", Int(acc * 100)))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(acc > 0.8 ? .green : acc > 0.6 ? .orange : .red)
            }
            Text(L("status.samples", state.totalSamples))
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
                            Text(localised: "ax.required")
                                .font(.system(size: 12.5, weight: .medium))
                            Text(localised: "ax.explain")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button(L("ax.openSettings")) { AXPermission.openSettings() }
                                Button(L("ax.recheck")) { state.refreshAccessibility() }
                            }
                            .controlSize(.small)
                            .padding(.top, 2)
                        }
                    }
                }
            }

            // First section on purpose: these two decide whether a tap
            // registers at all and whether it is allowed to fire, so they are
            // the first thing to reach for when nothing seems to happen.
            Section(L("section.detection")) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(localised: "sensitivity.title")
                        Spacer()
                        Text(sensitivityLabel)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.sensitivity, in: 0...100) { _ in state.save() }
                    HStack {
                        Text(localised: "sensitivity.hard").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text(localised: "sensitivity.light").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(localised: "confidence.title")
                        Spacer()
                        Text(L("confidence.value", Int(state.minConfidence * 100)))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.minConfidence, in: 0.25...0.95) { _ in state.save() }
                    Text(localised: "confidence.hint")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }

            Section(L("section.shortcuts")) {
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
                        .help(L("shortcut.removeHelp"))
                    }
                }

                HStack {
                    Button(L("shortcuts.restore")) { state.restoreDefaultBindings() }
                        .disabled(state.usingDefaultBindings)
                    Button(L("shortcuts.clearAll")) { state.clearAllBindings() }
                        .disabled(state.bindings.isEmpty)
                    Spacer()
                }
                .controlSize(.small)
            }

            Section(L("section.behaviour")) {
                Toggle(L("toggle.runShortcuts"), isOn: $state.actionsEnabled)
                    .onChange(of: state.actionsEnabled) { _, on in
                        if on && !AXPermission.isTrusted { AXPermission.requestAccess() }
                        state.refreshAccessibility()
                        state.save()
                    }

                HStack {
                    Toggle(L("toggle.showToast"), isOn: $state.showToast)
                        .onChange(of: state.showToast) { _, _ in state.save() }
                    Spacer()
                    Button(L("button.try")) {
                        ToastPresenter.shared.show(
                            zone: state.armedZone.title,
                            shortcut: state.bindings[state.armedZone]?.display ?? "⌃←")
                    }
                    .controlSize(.small)
                    .disabled(!state.showToast)
                }

                Picker(L("language.title"), selection: $state.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.title).tag(lang)
                    }
                }
                .onChange(of: state.language) { _, _ in state.save() }
            }

            Section(L("section.calibration")) {
                HStack {
                    Button(L("calibration.clearZone", state.armedZone.title)) { state.clear(state.armedZone) }
                        .disabled((state.counts[state.armedZone] ?? 0) == 0)
                    Button(L("calibration.clearAll"), role: .destructive) { state.clear(nil) }
                        .disabled(state.totalSamples == 0)
                    Spacer()
                }
                .controlSize(.small)

                Button(L("calibration.showIntro")) {
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
