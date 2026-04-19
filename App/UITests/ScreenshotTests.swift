import XCTest

/// App Store screenshot automation.
///
/// Run via Fastlane: `bundle exec fastlane screenshots`
/// Or manually: Product → Test (Cmd+U) with the UITests scheme selected.
@MainActor
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
        sleep(2)
        snapshot("01_LoginScreen")
    }

    func test02_WorkspaceList() {
        let workspacesTitle = app.staticTexts["Workspaces"]
        if workspacesTitle.waitForExistence(timeout: 10) {
            snapshot("02_WorkspaceList")
        }
    }

    func test03_WorkspaceDetail() {
        let firstCard = app.cells.firstMatch
        if firstCard.waitForExistence(timeout: 10) {
            firstCard.tap()
            sleep(2)
            snapshot("03_WorkspaceDetail")
        }
    }

    func test04_Terminal() {
        let firstCard = app.cells.firstMatch
        if firstCard.waitForExistence(timeout: 10) {
            firstCard.tap()
            sleep(2)
            let terminalButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'main' OR label CONTAINS 'terminal'")
            ).firstMatch
            if terminalButton.waitForExistence(timeout: 5) {
                terminalButton.tap()
                sleep(3)
                snapshot("04_Terminal")
            }
        }
    }

    func test05_Settings() {
        let avatarButton = app.buttons.firstMatch
        if avatarButton.waitForExistence(timeout: 10) {
            avatarButton.tap()
            sleep(1)
            let settingsTitle = app.staticTexts["Settings"]
            if settingsTitle.waitForExistence(timeout: 3) {
                snapshot("05_Settings")
            }
        }
    }
}
