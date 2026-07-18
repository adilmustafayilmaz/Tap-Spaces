import Foundation

enum Zone: String, CaseIterable, Codable, Identifiable {
    case topLeft = "TL", topRight = "TR", bottomLeft = "BL", bottomRight = "BR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return L("zone.topLeft")
        case .topRight: return L("zone.topRight")
        case .bottomLeft: return L("zone.bottomLeft")
        case .bottomRight: return L("zone.bottomRight")
        }
    }

    /// Drives which outer corner a tile's badge sits in, so the counts hug the
    /// edges of the board instead of crowding the divider down the middle.
    var isLeft: Bool { self == .topLeft || self == .bottomLeft }
}

struct TrainingSample: Codable {
    let label: Zone
    let feats: [Double]
}

/// Distance-weighted k-nearest-neighbour over standardised features.
/// Small training sets, no dependencies, and it retrains instantly.
final class KNN: Codable {
    var k: Int = 5
    var samples: [TrainingSample] = []

    private var standardised: [[Double]] = []
    private var labels: [Zone] = []
    private var mean: [Double] = []
    private var std: [Double] = []
    private var dirty = true

    enum CodingKeys: String, CodingKey { case k, samples }

    init() {}

    func add(_ label: Zone, _ feats: [Double]) {
        samples.append(TrainingSample(label: label, feats: feats))
        dirty = true
    }

    func clear(_ label: Zone?) {
        if let label { samples.removeAll { $0.label == label } } else { samples.removeAll() }
        dirty = true
    }

    /// Swap in a whole training set (used when restoring from disk).
    /// Assigning `samples` directly would leave the fitted cache stale.
    ///
    /// The state file is plain JSON that a user — or any other process — can
    /// edit, so nothing in it is trusted: a ragged feature vector would crash
    /// `fit()` on an out-of-range index, and a non-positive `k` would trap in
    /// `predict`'s `prefix`.
    func replaceSamples(_ new: [TrainingSample], k: Int) {
        samples = new.filter { $0.feats.count == Features.dimension }
        self.k = min(max(k, 1), 25)
        dirty = true
    }

    func counts() -> [Zone: Int] {
        var c = [Zone: Int]()
        for z in Zone.allCases { c[z] = 0 }
        for s in samples { c[s.label, default: 0] += 1 }
        return c
    }

    /// Zones with enough samples to take part in a prediction.
    var trainedZoneCount: Int { counts().values.filter { $0 >= 3 }.count }

    /// One trained zone is a legitimate setup — it turns any tap into a single
    /// trigger. It just cannot discriminate, so every tap scores 100% for that
    /// zone; the UI calls that out rather than pretending it is accuracy.
    var isReady: Bool { trainedZoneCount >= 1 }

    var canDiscriminate: Bool { trainedZoneCount >= 2 }

    private func fit() {
        guard dirty, !samples.isEmpty else { return }
        let d = samples[0].feats.count
        mean = [Double](repeating: 0, count: d)
        std = [Double](repeating: 0, count: d)

        for s in samples { for i in 0..<d { mean[i] += s.feats[i] } }
        for i in 0..<d { mean[i] /= Double(samples.count) }
        for s in samples { for i in 0..<d { std[i] += pow(s.feats[i] - mean[i], 2) } }
        for i in 0..<d { std[i] = max(sqrt(std[i] / Double(samples.count)), 1e-6) }

        standardised = samples.map { s in (0..<d).map { (s.feats[$0] - mean[$0]) / std[$0] } }
        labels = samples.map(\.label)
        dirty = false
    }

    func predict(_ feats: [Double]) -> (zone: Zone, scores: [Zone: Double])? {
        fit()
        guard standardised.count >= 2, feats.count == mean.count else { return nil }
        let q = (0..<feats.count).map { (feats[$0] - mean[$0]) / std[$0] }

        var dists = [(Double, Zone)]()
        dists.reserveCapacity(standardised.count)
        for (i, row) in standardised.enumerated() {
            var sum = 0.0
            for j in 0..<q.count { sum += pow(row[j] - q[j], 2) }
            dists.append((sqrt(sum), labels[i]))
        }
        dists.sort { $0.0 < $1.0 }

        var weights = [Zone: Double]()
        for z in Zone.allCases { weights[z] = 0 }
        for (dist, label) in dists.prefix(min(k, dists.count)) {
            weights[label, default: 0] += 1.0 / (dist + 1e-6)
        }
        let total = weights.values.reduce(0, +) + 1e-9
        let scores = weights.mapValues { $0 / total }
        guard let best = scores.max(by: { $0.value < $1.value })?.key else { return nil }
        return (best, scores)
    }

    /// Leave-one-out accuracy — an honest read that never scores a sample
    /// against itself.
    func crossValidate() -> Double? {
        guard samples.count >= 8 else { return nil }
        fit()
        var correct = 0
        for i in 0..<standardised.count {
            var dists = [(Double, Zone)]()
            for j in 0..<standardised.count where j != i {
                var sum = 0.0
                for d in 0..<standardised[i].count {
                    sum += pow(standardised[j][d] - standardised[i][d], 2)
                }
                dists.append((sqrt(sum), labels[j]))
            }
            dists.sort { $0.0 < $1.0 }
            var weights = [Zone: Double]()
            for (dist, label) in dists.prefix(min(k, dists.count)) {
                weights[label, default: 0] += 1.0 / (dist + 1e-6)
            }
            if weights.max(by: { $0.value < $1.value })?.key == labels[i] { correct += 1 }
        }
        return Double(correct) / Double(standardised.count)
    }
}
