import XCTest

/// App Store screenshot automation.
///
/// Run via Fastlane: `bundle exec fastlane screenshots`
/// Or manually: Product → Test (Cmd+U) with the UITests scheme selected.
///
/// Each test method captures one screenshot at a key screen. The app must
/// be signed into a real Coder deployment for the workspace/terminal
/// screenshots to show real content. For the login screen, launch fresh.
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    // MARK: - Screenshots

    func test01_LoginScreen() {
        // The app launches to the login screen if not signed in.
        // If already signed in, this captures whatever the first screen is.
        sleep(2) // wait for launch animation
        snapshot("01_LoginScreen")
    }

    func test02_WorkspaceList() {
        // Wait for workspace list to load after sign-in.
        let workspacesTitle = app.staticTexts["Workspaces"]
        if workspacesTitle.waitForExistence(timeout: 10) {
            snapshot("02_WorkspaceList")
        }
    }

    func test03_WorkspaceDetail() {
        // Tap first workspace card to navigate to detail.
        let firstCard = app.cells.firstMatch
        if firstCard.waitForExistence(timeout: 10) {
            firstCard.tap()
            sleep(2) // wait for detail to load
            snapshot("03_WorkspaceDetail")
        }
    }

    func test04_Terminal() {
        // From workspace detail, tap the first connected agent to open terminal.
        let firstCard = app.cells.firstMatch
        if firstCard.waitForExistence(timeout: 10) {
            firstCard.tap()
            sleep(2)

            // Look for agent row with terminal icon
            let terminalButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'main' OR label CONTAINS 'terminal'")
            ).firstMatch
            if terminalButton.waitForExistence(timeout: 5) {
                terminalButton.tap()
                sleep(3) // wait for terminal to connect + render
                snapshot("04_Terminal")
            }
        }
    }

    func test05_Settings() {
        // Tap the avatar button to open settings.
        let avatarButton = app.buttons.firstMatch
        if avatarButton.waitForExistence(timeout: 10) {
            avatarButton.tap()
            sleep(1)

            // Look for settings sheet
            let settingsTitle = app.staticTexts["Settings"]
            if settingsTitle.waitForExistence(timeout: 3) {
                snapshot("05_Settings")
            }
        }
    }
}
