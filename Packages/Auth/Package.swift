// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Auth",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Auth", targets: ["Auth"]),
    ],
    dependencies: [
        .package(path: "../CoderAPI"),
    ],
    targets: [
        .target(
            name: "Auth",
            dependencies: ["CoderAPI"]
        ),
        .testTarget(
            name: "AuthTests",
            dependencies: ["Auth"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
