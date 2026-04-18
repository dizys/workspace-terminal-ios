// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PTYTransport",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PTYTransport", targets: ["PTYTransport"]),
    ],
    dependencies: [
        .package(path: "../CoderAPI"),
    ],
    targets: [
        .target(
            name: "PTYTransport",
            dependencies: ["CoderAPI"]
        ),
        .testTarget(
            name: "PTYTransportTests",
            dependencies: ["PTYTransport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
