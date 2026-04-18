// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TerminalFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TerminalFeature", targets: ["TerminalFeature"]),
    ],
    dependencies: [
        .package(path: "../CoderAPI"),
        .package(path: "../PTYTransport"),
        .package(path: "../TerminalUI"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.16.0"),
    ],
    targets: [
        .target(
            name: "TerminalFeature",
            dependencies: [
                "CoderAPI",
                "PTYTransport",
                "TerminalUI",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "TerminalFeatureTests",
            dependencies: [
                "TerminalFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
