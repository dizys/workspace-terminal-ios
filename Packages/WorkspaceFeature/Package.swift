// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkspaceFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WorkspaceFeature", targets: ["WorkspaceFeature"]),
    ],
    dependencies: [
        .package(path: "../CoderAPI"),
        .package(path: "../DesignSystem"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.16.0"),
    ],
    targets: [
        .target(
            name: "WorkspaceFeature",
            dependencies: [
                "CoderAPI",
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "WorkspaceFeatureTests",
            dependencies: [
                "WorkspaceFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
