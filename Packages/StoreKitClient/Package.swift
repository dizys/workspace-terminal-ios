// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StoreKitClient",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StoreKitClient", targets: ["StoreKitClient"]),
    ],
    targets: [
        .target(
            name: "StoreKitClient"
        ),
        .testTarget(
            name: "StoreKitClientTests",
            dependencies: ["StoreKitClient"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
