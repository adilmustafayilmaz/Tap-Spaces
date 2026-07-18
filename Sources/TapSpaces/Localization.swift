import Foundation
import SwiftUI

/// The user's in-app language choice. `system` defers to macOS.
enum AppLanguage: String, CaseIterable, Codable {
    case system, en, tr

    /// Language names are shown in their own language on purpose — a Turkish
    /// speaker stuck in the English UI still recognises "Türkçe".
    var title: String {
        switch self {
        case .system: return L("language.system")
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }
}

/// The bundle lookups resolve against. `.main` follows the system language;
/// an explicit choice points at that language's `.lproj` sub-bundle, which is
/// what makes in-app switching take effect immediately, without a relaunch.
enum L10n {
    private(set) static var bundle: Bundle = .main

    static func apply(_ choice: AppLanguage) {
        switch choice {
        case .system:
            bundle = .main
        case .en, .tr:
            bundle = Bundle.main.path(forResource: choice.rawValue, ofType: "lproj")
                .flatMap(Bundle.init(path:)) ?? .main
        }
    }
}

/// Looks a string up in the app bundle's `.lproj` catalogues.
///
/// The bundle is assembled by `build.sh` rather than Xcode, so the catalogues
/// live in `Contents/Resources/{en,tr}.lproj/Localizable.strings` and resolve
/// against the main bundle. English is the development language; macOS falls
/// back to it for any locale that is not Turkish.
func L(_ key: String) -> String {
    L10n.bundle.localizedString(forKey: key, value: nil, table: nil)
}

/// Formatted variant. Turkish writes the percent sign before the number, so the
/// argument order and placement live in the catalogue, not in the call site.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.bundle.localizedString(forKey: key, value: nil, table: nil),
           arguments: args)
}

extension Text {
    /// `Text(localised:)` rather than `Text(_:)` so the key is never mistaken
    /// for a literal that just happens to look like one.
    init(localised key: String) {
        self.init(verbatim: L(key))
    }
}
