// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PTYTransport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PTYTransport", targets: ["PTYTransport"]),
    ],
    dependencies: [
        .package(path: "../CoderAPI"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.16.0"),
    ],
    targets: [
        .target(
            name: "PTYTransport",
            dependencies: [
                "CoderAPI",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "PTYTransportTests",
            dependencies: [
                "PTYTransport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
