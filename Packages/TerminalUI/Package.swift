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
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "TerminalUI",
            dependencies: [
                "DesignSystem",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
        .testTarget(
            name: "TerminalUITests",
            dependencies: ["TerminalUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
