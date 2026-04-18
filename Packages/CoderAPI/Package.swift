// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoderAPI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoderAPI", targets: ["CoderAPI"]),
    ],
    targets: [
        .target(
            name: "CoderAPI"
        ),
        .testTarget(
            name: "CoderAPITests",
            dependencies: ["CoderAPI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
