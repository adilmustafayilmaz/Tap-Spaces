import Accelerate
import Foundation

/// Real FFT over a fixed power-of-two size. Accelerate's radix-2 transform
/// requires that, so tap windows get truncated or zero-padded to fit; the
/// classifier is trained through this same path so the framing stays consistent.
final class FFTProcessor {
    let n: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private var window: [Float]

    init(n: Int) {
        self.n = n
        self.log2n = vDSP_Length(log2(Double(n)).rounded())
        self.setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Magnitude spectrum, `n/2` bins. Bin `i` sits at `i * sampleRate / n` Hz.
    func magnitudes(_ x: [Float]) -> [Float] {
        var input = [Float](repeating: 0, count: n)
        let count = min(x.count, n)
        if count > 0 { input.replaceSubrange(0..<count, with: x[0..<count]) }
        vDSP_vmul(input, 1, window, 1, &input, 1, vDSP_Length(n))

        let half = n / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var mags = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                input.withUnsafeBufferPointer { inp in
                    inp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { cp in
                        vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))
            }
        }
        // Bin 0 packs DC in real and Nyquist in imag. Everything below 60 Hz is
        // discarded anyway, so leave it as-is rather than unpacking.
        return mags
    }
}

enum Features {
    static let dimension = 56

    private static let fftFull = FFTProcessor(n: 8192)
    private static let fftEarly = FFTProcessor(n: 1024)

    /// Mean-removed log magnitude across `count` geometrically spaced bands.
    ///
    /// Removing the mean throws away absolute loudness, which mostly reflects
    /// how hard the table was hit rather than where.
    private static func logBands(_ mags: [Float], sampleRate: Double, fftSize: Int,
                                 lo: Double, hi: Double, count: Int) -> [Double] {
        var out = [Double](repeating: -20, count: count)
        let binHz = sampleRate / Double(fftSize)
        let ratio = pow(hi / lo, 1.0 / Double(count))

        for b in 0..<count {
            let f0 = lo * pow(ratio, Double(b))
            let f1 = f0 * ratio
            let i0 = max(1, Int(ceil(f0 / binHz)))
            let i1 = min(mags.count - 1, Int(floor(f1 / binHz)))
            guard i0 <= i1 else { continue }
            var sum = 0.0
            for i in i0...i1 { sum += Double(mags[i]) }
            out[b] = log(sum / Double(i1 - i0 + 1) + 1e-9)
        }
        let mean = out.reduce(0, +) / Double(count)
        return out.map { $0 - mean }
    }

    private static func centroid(_ mags: [Float], sampleRate: Double, fftSize: Int) -> Double {
        let binHz = sampleRate / Double(fftSize)
        var num = 0.0, den = 0.0
        for i in 1..<mags.count {
            let m = Double(mags[i])
            num += m * (Double(i) * binHz)
            den += m
        }
        return den > 1e-9 ? num / den : 0
    }

    private static func rms(_ x: ArraySlice<Float>) -> Double {
        guard !x.isEmpty else { return 0 }
        var sum = 0.0
        for v in x { sum += Double(v) * Double(v) }
        return (sum / Double(x.count)).squareRoot()
    }

    /// Turn a captured tap window into the 56-dimension feature vector.
    /// `onset` is the sample index where the transient begins.
    static func extract(window raw: [Float], onset: Int, sampleRate: Double) -> [Double] {
        var x = raw
        let mean = x.reduce(0, +) / Float(x.count)
        var negMean = -mean
        vDSP_vsadd(x, 1, &negMean, &x, 1, vDSP_Length(x.count))

        var peak: Float = 0
        vDSP_maxmgv(x, 1, &peak, vDSP_Length(x.count))
        let energyDb = 20.0 * log10(Double(peak) + 1e-9)
        var scale = 1.0 / (peak + 1e-9)
        vDSP_vsmul(x, 1, &scale, &x, 1, vDSP_Length(x.count))

        let earlyEnd = min(x.count, onset + Int(0.015 * sampleRate))
        let lateStart = min(x.count, onset + Int(0.060 * sampleRate))
        let early = Array(x[onset..<earlyEnd])
        let late = Array(x[lateStart...])

        var f = [Double]()
        f.reserveCapacity(dimension)

        let magFull = fftFull.magnitudes(x)
        let magEarly = fftEarly.magnitudes(early)
        let magLate = fftFull.magnitudes(late)

        f += logBands(magFull, sampleRate: sampleRate, fftSize: fftFull.n,
                      lo: 60, hi: 18000, count: 20)
        f += logBands(magEarly, sampleRate: sampleRate, fftSize: fftEarly.n,
                      lo: 100, hi: 18000, count: 12)
        f += logBands(magLate, sampleRate: sampleRate, fftSize: fftFull.n,
                      lo: 100, hi: 12000, count: 12)

        // Decay shape: normalised log RMS across six slices of the tap.
        let tail = x[onset...]
        let sliceLen = max(1, tail.count / 6)
        var env = [Double]()
        for s in 0..<6 {
            let a = tail.startIndex + s * sliceLen
            let b = (s == 5) ? tail.endIndex : min(tail.endIndex, a + sliceLen)
            env.append(log(rms(x[a..<b]) + 1e-9))
        }
        let envMax = env.max() ?? 0
        f += env.map { $0 - envMax }

        let cEarly = centroid(magEarly, sampleRate: sampleRate, fftSize: fftEarly.n)
        let cLate = centroid(magLate, sampleRate: sampleRate, fftSize: fftFull.n)
        f.append(cEarly / 1000)
        f.append(cLate / 1000)
        f.append((cEarly - cLate) / 1000)

        let eEarly = rms(early[...]) + 1e-9
        let eLate = rms(late[...]) + 1e-9
        f.append(log(eLate / eEarly))            // direct-to-reverberant ratio

        var crossings = 0
        for i in (onset + 1)..<x.count where (x[i] < 0) != (x[i - 1] < 0) { crossings += 1 }
        f.append(Double(crossings) / Double(max(1, x.count - onset - 1)) * 10)

        f.append(energyDb / 10)
        return f
    }
}
