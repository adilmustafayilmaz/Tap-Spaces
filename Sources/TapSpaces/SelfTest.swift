import Foundation

/// Headless sanity check for the DSP and classifier paths, run with
/// `TapSpaces --selftest`. Synthesises taps whose spectra differ per zone the
/// way real table positions do, then checks the pipeline can separate them.
enum SelfTest {
    private struct RNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return state
        }
    }

    private static func gauss(_ rng: inout RNG) -> Double {
        let u1 = Double.random(in: 1e-9...1, using: &rng)
        let u2 = Double.random(in: 0...1, using: &rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    private static func fakeTap(_ zone: Zone, _ rng: inout RNG,
                                sampleRate: Double, pre: Int, post: Int) -> [Float] {
        let profile: ([Double], Double, Double)
        switch zone {
        case .topLeft:     profile = ([180, 640, 2100], 0.030, 0.55)
        case .topRight:    profile = ([210, 900, 3400], 0.022, 0.42)
        case .bottomLeft:  profile = ([150, 520, 1500], 0.045, 0.70)
        case .bottomRight: profile = ([260, 1100, 4200], 0.018, 0.35)
        }
        let (modes, tau, level) = profile

        var window = [Float](repeating: 0, count: pre + post)
        for i in 0..<pre { window[i] = Float(gauss(&rng) * 0.001) }

        // Detune and phase are drawn once per mode per tap. Re-drawing them per
        // sample would turn each resonance into white noise and erase exactly
        // the structure the classifier is supposed to key on.
        let resonances = modes.map { f -> (freq: Double, phase: Double) in
            (f * (1 + gauss(&rng) * 0.02), Double.random(in: 0...(2 * .pi), using: &rng))
        }
        let force = level * (1 + gauss(&rng) * 0.35)

        for i in 0..<post {
            let t = Double(i) / sampleRate
            var v = 0.0
            for r in resonances {
                v += exp(-t / tau) * sin(2 * .pi * r.freq * t + r.phase)
            }
            v += exp(-t / 0.002) * gauss(&rng) * 2      // contact click
            window[pre + i] = Float(v * force)
        }
        for i in 0..<window.count { window[i] += Float(gauss(&rng) * 0.002) }
        return window
    }

    static func run() -> Int32 {
        let sr = 48000.0
        let pre = Int(0.010 * sr), post = Int(0.190 * sr)
        var rng = RNG(state: 0x2545F4914F6CDD1D)
        var failures = 0

        func check(_ label: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "PASS" : "FAIL")  \(label)  \(detail)")
            if !ok { failures += 1 }
        }

        // 1. Feature vector shape and finiteness
        let sample = fakeTap(.topLeft, &rng, sampleRate: sr, pre: pre, post: post)
        let feats = Features.extract(window: sample, onset: pre, sampleRate: sr)
        check("feature dim", feats.count == Features.dimension,
              "\(feats.count) (expected \(Features.dimension))")
        check("feature finite", feats.allSatisfy { $0.isFinite }, "all finite")

        // 2. Loudness invariance — the same tap hit twice as hard should land
        //    in nearly the same place, or the model would learn hit force.
        var quiet = sample, loud = sample
        for i in 0..<quiet.count { quiet[i] *= 0.25; loud[i] *= 2.5 }
        let fq = Features.extract(window: quiet, onset: pre, sampleRate: sr)
        let fl = Features.extract(window: loud, onset: pre, sampleRate: sr)
        // Ignore the final absolute-level dimension, which is meant to vary.
        var drift = 0.0
        for i in 0..<(Features.dimension - 1) { drift = max(drift, abs(fq[i] - fl[i])) }
        check("loudness invariance", drift < 0.05, String(format: "max drift %.5f", drift))

        // 3. Train and score
        let model = KNN()
        for zone in Zone.allCases {
            for _ in 0..<25 {
                let w = fakeTap(zone, &rng, sampleRate: sr, pre: pre, post: post)
                model.add(zone, Features.extract(window: w, onset: pre, sampleRate: sr))
            }
        }
        check("sample count", model.samples.count == 100, "\(model.samples.count)")
        check("isReady", model.isReady, "\(model.isReady)")

        let loo = model.crossValidate() ?? 0
        check("leave-one-out", loo > 0.9, String(format: "%.3f", loo))

        var correct = 0
        let trials = 80
        for _ in 0..<trials {
            let zone = Zone.allCases.randomElement(using: &rng)!
            let w = fakeTap(zone, &rng, sampleRate: sr, pre: pre, post: post)
            let f = Features.extract(window: w, onset: pre, sampleRate: sr)
            if model.predict(f)?.zone == zone { correct += 1 }
        }
        let holdout = Double(correct) / Double(trials)
        check("holdout accuracy", holdout > 0.9, String(format: "%.3f", holdout))

        // 4. Persistence round trip
        let encoded = try! JSONEncoder().encode(model)
        let decoded = try! JSONDecoder().decode(KNN.self, from: encoded)
        check("codable round trip", decoded.samples.count == model.samples.count,
              "\(decoded.samples.count) samples")
        let reFeats = Features.extract(window: sample, onset: pre, sampleRate: sr)
        check("decoded model predicts", decoded.predict(reFeats) != nil,
              "\(decoded.predict(reFeats)?.zone.rawValue ?? "nil")")

        // 5. Hostile state file: ragged feature vectors and a non-positive k
        //    must be rejected on load rather than trapping later in fit/predict.
        let hostile = KNN()
        hostile.replaceSamples([TrainingSample(label: .topLeft, feats: [1, 2, 3])], k: -3)
        check("hostile load rejected", hostile.samples.isEmpty && hostile.k >= 1,
              "\(hostile.samples.count) kept, k=\(hostile.k)")

        // 6. Key action formatting and codability
        let action = KeyAction(keyCode: 123, modifiers: 262144)   // ⌃←
        check("key display", action.display.contains("←"), action.display)
        let ka = try! JSONDecoder().decode(
            KeyAction.self, from: try! JSONEncoder().encode(action))
        check("key round trip", ka == action, ka.display)

        print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
        return failures == 0 ? 0 : 1
    }
}
