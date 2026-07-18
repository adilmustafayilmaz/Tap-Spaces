import Foundation
import SwiftUI

/// Looks a string up in the app bundle's `.lproj` catalogues.
///
/// The bundle is assembled by `build.sh` rather than Xcode, so the catalogues
/// live in `Contents/Resources/{en,tr}.lproj/Localizable.strings` and resolve
/// against the main bundle. English is the development language; macOS falls
/// back to it for any locale that is not Turkish.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Formatted variant. Turkish writes the percent sign before the number, so the
/// argument order and placement live in the catalogue, not in the call site.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

extension Text {
    /// `Text(localised:)` rather than `Text(_:)` so the key is never mistaken
    /// for a literal that just happens to look like one.
    init(localised key: String) {
        self.init(verbatim: L(key))
    }
}
