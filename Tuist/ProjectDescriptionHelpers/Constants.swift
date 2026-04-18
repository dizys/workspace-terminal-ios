import ProjectDescription

public enum Constants {
    public static let bundleIdPrefix = "app.workspaceterminal"
    public static let appBundleId = "\(bundleIdPrefix).ios"
    public static let testsBundleId = "\(bundleIdPrefix).ios.tests"
    public static let deploymentTarget = DeploymentTargets.iOS("17.0")
    public static let destinations: Destinations = [.iPhone, .iPad]
}
