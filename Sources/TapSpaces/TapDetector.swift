import AVFoundation
import Accelerate
import Foundation

/// Captures the built-in microphone, finds tap transients, and hands each
/// captured window to a callback on a background queue.
///
/// macOS exposes the MacBook mic array as a single beamformed channel, so
/// there is no inter-channel delay to triangulate with. Localisation happens
/// downstream from the acoustic fingerprint of each tap instead.
final class TapDetector {
    var onTap: (([Float], Int, Double) -> Void)?   // window, onset index, sampleRate
    var onLevel: ((Float) -> Void)?

    /// 0–100. Higher trips on lighter taps.
    var sensitivity: Double = 50

    private let engine = AVAudioEngine()
    private let work = DispatchQueue(label: "tapspaces.features", qos: .userInitiated)

    private var sampleRate: Double = 48000
    private var pre = 0
    private var post = 0
    private var windowLength: Int { pre + post }

    private var ring: [Float] = []
    private var ringIndex = 0
    private var preRoll: [Float] = []

    private var capturing = false
    private var captured: [Float] = []
    private var lastTap: CFTimeInterval = 0
    private var noiseFloor: Float = 1e-4
    private var hpState: Float = 0

    private let refractory: CFTimeInterval = 0.25

    private(set) var isRunning = false

    /// Measured ambient noise on this hardware peaks near 0.014 after the high
    /// pass, so even the most sensitive setting has to stay above that or the
    /// detector free-runs on room noise.
    private var absoluteFloor: Float {
        let s = min(max(sensitivity, 0), 100) / 100
        return Float(pow(10.0, -0.8 - 1.0 * s))     // 0.158 (hard knock) … 0.016 (light)
    }

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "TapSpaces", code: 1, userInfo: [
                NSLocalizedDescriptionKey: L("error.noMicInput")
            ])
        }

        sampleRate = format.sampleRate
        pre = Int(0.010 * sampleRate)
        post = Int(0.190 * sampleRate)
        ring = [Float](repeating: 0, count: Int(0.05 * sampleRate))
        ringIndex = 0
        preRoll = [Float](repeating: 0, count: pre)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        let block = Array(UnsafeBufferPointer(start: channel, count: n))

        // First difference is a cheap high pass. Taps are broadband transients;
        // fan noise and room rumble sit low and get suppressed.
        var hp = [Float](repeating: 0, count: n)
        hp[0] = block[0] - hpState
        for i in 1..<n { hp[i] = block[i] - block[i - 1] }
        hpState = block[n - 1]

        var rms: Float = 0
        vDSP_rmsqv(hp, 1, &rms, vDSP_Length(n))
        onLevel?(rms)

        // Ring buffer keeps the audio just before an onset available.
        let ringSize = ring.count
        var written = 0
        while written < n {
            let chunk = min(n - written, ringSize - ringIndex)
            ring.replaceSubrange(ringIndex..<(ringIndex + chunk),
                                 with: block[written..<(written + chunk)])
            ringIndex = (ringIndex + chunk) % ringSize
            written += chunk
        }

        if capturing {
            captured.append(contentsOf: block)
            if captured.count >= post {
                var window = preRoll
                window.append(contentsOf: captured[0..<post])
                capturing = false
                captured.removeAll(keepingCapacity: true)
                if window.count == windowLength {
                    let onset = pre
                    let sr = sampleRate
                    work.async { [weak self] in self?.onTap?(window, onset, sr) }
                }
            }
            return
        }

        let now = CACurrentMediaTime()
        let threshold = max(noiseFloor * 8, absoluteFloor)
        if rms > threshold && (now - lastTap) > refractory {
            // Snapshot the pre-onset audio now — the ring has already moved on
            // by the time the capture finishes.
            var linear = [Float](repeating: 0, count: ringSize)
            linear.replaceSubrange(0..<(ringSize - ringIndex), with: ring[ringIndex...])
            linear.replaceSubrange((ringSize - ringIndex)..<ringSize, with: ring[0..<ringIndex])
            let end = ringSize - n
            preRoll = (end >= pre) ? Array(linear[(end - pre)..<end])
                                   : [Float](repeating: 0, count: pre)
            lastTap = now
            capturing = true
            captured = block
        } else {
            noiseFloor = 0.995 * noiseFloor + 0.005 * rms
        }
    }
}
