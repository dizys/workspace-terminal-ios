// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(path: "../Auth"),
        .package(path: "../CoderAPI"),
        .package(path: "../DesignSystem"),
        .package(path: "../StoreKitClient"),
        .package(path: "../TerminalFeature"),
        .package(path: "../WorkspaceFeature"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.16.0"),
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                "Auth",
                "CoderAPI",
                "DesignSystem",
                "StoreKitClient",
                "TerminalFeature",
                "WorkspaceFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
