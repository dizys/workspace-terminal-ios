import ProjectDescription

let config = Config(
    compatibleXcodeVersions: ["16.0", "16.1", "16.2", "16.3", "16.4"],
    swiftVersion: "6.0",
    generationOptions: .options(
        enforceExplicitDependencies: true
    )
)
