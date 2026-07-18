// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapSpaces",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TapSpaces",
            path: "Sources/TapSpaces",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
