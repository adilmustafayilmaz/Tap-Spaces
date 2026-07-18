import AVFoundation
import AppKit
import Combine
import Foundation

enum Mode: String, Codable { case calibrate, live }

struct TapLog: Identifiable {
    let id = UUID()
    let text: String
    let zone: Zone
}

/// Everything the UI binds to, plus the wiring from detector → classifier →
/// keyboard shortcut.
@MainActor
final class AppState: ObservableObject {
    @Published var mode: Mode = .live
    @Published var armedZone: Zone = .topLeft
    @Published var sensitivity: Double = 50 { didSet { detector.sensitivity = sensitivity } }
    @Published var minConfidence: Double = 0.6
    @Published var actionsEnabled = true
    @Published var showToast = true
    @Published var bindings: [Zone: KeyAction] = [:]
    @Published var hasOnboarded = false

    /// Sent to the frontmost app when a zone is hit, unless the user rebinds or
    /// clears them. Chosen to be reversible and non-destructive: Mission
    /// Control and desktop switching change nothing the user can lose.
    static let defaultBindings: [Zone: KeyAction] = [
        .topLeft: KeyAction(keyCode: 126, modifiers: NSEvent.ModifierFlags.control.rawValue),
        .topRight: KeyAction(keyCode: 125, modifiers: NSEvent.ModifierFlags.control.rawValue),
        .bottomLeft: KeyAction(keyCode: 123, modifiers: NSEvent.ModifierFlags.control.rawValue),
        .bottomRight: KeyAction(keyCode: 124, modifiers: NSEvent.ModifierFlags.control.rawValue),
    ]

    @Published private(set) var level: Float = 0
    @Published private(set) var counts: [Zone: Int] = [:]
    @Published private(set) var accuracy: Double?
    @Published private(set) var lastZone: Zone?
    @Published private(set) var scores: [Zone: Double] = [:]
    @Published private(set) var log: [TapLog] = []
    @Published private(set) var micDenied = false
    @Published private(set) var startupError: String?
    @Published var accessibilityTrusted = false

    private let detector = TapDetector()
    private let model = KNN()
    private var levelThrottle = 0

    // ------------------------------------------------------------------
    // Persistence
    // ------------------------------------------------------------------
    private struct Persisted: Codable {
        var model: KNN
        var bindings: [String: KeyAction]
        var sensitivity: Double
        var minConfidence: Double
        var actionsEnabled: Bool
        /// Optional so a state file written before toasts existed still decodes
        /// — a missing non-optional key would fail the whole load and silently
        /// throw away the user's calibration.
        var showToast: Bool?
        var hasOnboarded: Bool?
    }

    /// True when nothing has ever been saved — used to decide whether to seed
    /// the default shortcuts and run onboarding.
    private var isFirstRun: Bool { !FileManager.default.fileExists(atPath: Self.storeURL.path) }

    private static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TapSpaces", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("state.json")
    }

    init() {
        let fresh = isFirstRun
        load()
        if fresh {
            bindings = Self.defaultBindings
            hasOnboarded = false
        }
        counts = model.counts()
        accuracy = model.crossValidate()
        detector.sensitivity = sensitivity

        detector.onLevel = { [weak self] value in
            guard let self else { return }
            // The audio thread ticks far faster than the UI needs.
            Task { @MainActor in
                self.levelThrottle += 1
                if self.levelThrottle % 6 == 0 { self.level = value }
            }
        }
        detector.onTap = { [weak self] window, onset, sampleRate in
            let feats = Features.extract(window: window, onset: onset, sampleRate: sampleRate)
            Task { @MainActor in self?.handle(feats) }
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        model.replaceSamples(p.model.samples, k: p.model.k)
        var restored = [Zone: KeyAction]()
        for (key, action) in p.bindings {
            if let z = Zone(rawValue: key) { restored[z] = action }
        }
        bindings = restored
        sensitivity = p.sensitivity
        minConfidence = p.minConfidence
        actionsEnabled = p.actionsEnabled
        showToast = p.showToast ?? true
        // Anyone upgrading from a build that predates onboarding has already
        // set the app up by hand; don't drag them back through the intro.
        hasOnboarded = p.hasOnboarded ?? true
    }

    /// Put every zone back on its default shortcut.
    func restoreDefaultBindings() {
        bindings = Self.defaultBindings
        save()
    }

    /// Unbind every zone. Taps still get classified, they just stop acting.
    func clearAllBindings() {
        bindings = [:]
        save()
    }

    var usingDefaultBindings: Bool { bindings == Self.defaultBindings }

    func save() {
        var encoded = [String: KeyAction]()
        for (zone, action) in bindings { encoded[zone.rawValue] = action }
        let p = Persisted(model: model, bindings: encoded, sensitivity: sensitivity,
                          minConfidence: minConfidence, actionsEnabled: actionsEnabled,
                          showToast: showToast, hasOnboarded: hasOnboarded)
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: Self.storeURL, options: .atomic)
        }
    }

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------
    func start() {
        accessibilityTrusted = AXPermission.isTrusted
        // Shortcuts are armed but macOS does not trust us: show the system
        // prompt rather than only a passive warning in the panel, so the app
        // gets registered in the Accessibility list under the right identity.
        // Skipped during onboarding, which asks for this in its own step —
        // shortcuts now default to on, so without this guard a first run would
        // fire the prompt before the app has explained what it is for.
        if hasOnboarded && actionsEnabled && !accessibilityTrusted {
            AXPermission.requestAccess()
        }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else { self.micDenied = true; return }
                do {
                    try self.detector.start()
                    self.startupError = nil
                } catch {
                    self.startupError = error.localizedDescription
                }
            }
        }
    }

    func stop() {
        detector.stop()
        save()
    }

    func refreshAccessibility() { accessibilityTrusted = AXPermission.isTrusted }

    // ------------------------------------------------------------------
    // Tap handling
    // ------------------------------------------------------------------
    private func handle(_ feats: [Double]) {
        switch mode {
        case .calibrate:
            model.add(armedZone, feats)
            counts = model.counts()
            accuracy = model.crossValidate()
            lastZone = armedZone
            append(L("log.trained", armedZone.title, counts[armedZone] ?? 0), armedZone)
            save()

        case .live:
            guard let (zone, scores) = model.predict(feats) else {
                append(L("log.untrained"), .topLeft)
                return
            }
            self.scores = scores
            lastZone = zone
            let confidence = scores[zone] ?? 0

            if actionsEnabled, confidence >= minConfidence, let action = bindings[zone] {
                if AXPermission.isTrusted {
                    action.post()
                    // Toast after posting: the keystroke has already gone to the
                    // frontmost app, so nothing can race with it.
                    if showToast {
                        ToastPresenter.shared.show(zone: zone.title, shortcut: action.display)
                    }
                    append(L("log.fired", zone.title, Int(confidence * 100), action.display), zone)
                } else {
                    accessibilityTrusted = false
                    append(L("log.noAX", zone.title), zone)
                }
            } else if actionsEnabled, confidence < minConfidence {
                append(L("log.lowConfidence", zone.title, Int(confidence * 100)), zone)
            } else {
                append(L("log.predicted", zone.title, Int(confidence * 100)), zone)
            }
        }
    }

    private func append(_ text: String, _ zone: Zone) {
        log.insert(TapLog(text: text, zone: zone), at: 0)
        if log.count > 40 { log.removeLast() }
    }

    // ------------------------------------------------------------------
    // Model editing
    // ------------------------------------------------------------------
    func clear(_ zone: Zone?) {
        model.clear(zone)
        counts = model.counts()
        accuracy = model.crossValidate()
        scores = [:]
        save()
        append(L("log.cleared", zone?.title ?? L("log.all")), zone ?? .topLeft)
    }

    var isReady: Bool { model.isReady }
    var canDiscriminate: Bool { model.canDiscriminate }
    var trainedZoneCount: Int { model.trainedZoneCount }
    var totalSamples: Int { model.samples.count }
}
