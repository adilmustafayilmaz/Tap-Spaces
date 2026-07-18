import AppKit
import Foundation

/// Once a day, asks GitHub for the latest release tag and compares it with
/// the running version.
///
/// This is the only network request the app ever makes, and the only thing
/// that travels is the request itself — no identifiers, no telemetry. The
/// response is public release metadata. Nothing is downloaded or installed
/// automatically; a newer version just surfaces as a menu bar item that
/// opens the releases page.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?

    static let releasesPage =
        URL(string: "https://github.com/adilmustafayilmaz/Tap-Spaces/releases/latest")!
    private static let api =
        URL(string: "https://api.github.com/repos/adilmustafayilmaz/Tap-Spaces/releases/latest")!

    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func start() {
        check()
        let day: TimeInterval = 24 * 60 * 60
        let timer = Timer(timeInterval: day, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        // A loose tolerance lets the system batch the wakeup; an update can
        // comfortably be a few minutes late.
        timer.tolerance = 60 * 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check() {
        var request = URLRequest(url: Self.api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = object["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            Task { @MainActor in
                guard let self else { return }
                self.availableVersion =
                    Self.isNewer(latest, than: self.currentVersion) ? latest : nil
            }
        }.resume()
    }

    static func open() {
        NSWorkspace.shared.open(releasesPage)
    }

    /// Numeric dotted-version compare; missing components count as zero.
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
