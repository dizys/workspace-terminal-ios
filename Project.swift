import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "WorkspaceTerminal",
    options: .options(
        defaultKnownRegions: ["en", "Base"],
        developmentRegion: "en"
    ),
    packages: [
        .local(path: "Packages/AppFeature"),
        .local(path: "Packages/Auth"),
        .local(path: "Packages/CoderAPI"),
        .local(path: "Packages/DesignSystem"),
        .local(path: "Packages/PTYTransport"),
        .local(path: "Packages/StoreKitClient"),
        .local(path: "Packages/TerminalFeature"),
        .local(path: "Packages/TerminalUI"),
        .local(path: "Packages/TestSupport"),
        .local(path: "Packages/WorkspaceFeature"),
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "DEVELOPMENT_TEAM": "$(DEVELOPMENT_TEAM)",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "WorkspaceTerminal",
            destinations: Constants.destinations,
            product: .app,
            bundleId: Constants.appBundleId,
            deploymentTargets: Constants.deploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Workspace Terminal",
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "1",
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                ],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                ],
                "ITSAppUsesNonExemptEncryption": false,
                "UIUserInterfaceStyle": "Dark",
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": true,
                    "UISceneConfigurations": [:],
                ],
            ]),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [
                .package(product: "AppFeature"),
                .package(product: "TerminalFeature"),
            ]
        ),
        .target(
            name: "WorkspaceTerminalTests",
            destinations: Constants.destinations,
            product: .unitTests,
            bundleId: Constants.testsBundleId,
            deploymentTargets: Constants.deploymentTarget,
            sources: ["App/Tests/**"],
            dependencies: [
                .target(name: "WorkspaceTerminal"),
                .package(product: "TestSupport"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "WorkspaceTerminal",
            shared: true,
            buildAction: .buildAction(targets: ["WorkspaceTerminal"]),
            testAction: .targets(
                ["WorkspaceTerminalTests"],
                configuration: .debug
            ),
            runAction: .runAction(configuration: .debug),
            archiveAction: .archiveAction(configuration: .release)
        ),
    ]
)
