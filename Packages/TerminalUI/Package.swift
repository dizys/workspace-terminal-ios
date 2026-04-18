    // swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TerminalUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TerminalUI", targets: ["TerminalUI"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "TerminalUI",
            dependencies: ["DesignSystem"]
        ),
        .testTarget(
            name: "TerminalUITests",
            dependencies: ["TerminalUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
