import XCTest

final class SourceControlUITests: XCTestCase {
    @MainActor
    func testToolbarAndKeyboardWorkspaceSwitching() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let picker = app.descendants(matching: .any)["workspaceModePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "The workspace picker should appear in the unified toolbar.")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(
            app.descendants(matching: .any)["sourceControlWorkspace"].waitForExistence(timeout: 5),
            "Command-2 should show Source Control."
        )

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            app.descendants(matching: .any)["consoleWorkspace"].waitForExistence(timeout: 5),
            "Command-1 should return to the console."
        )
    }

    @MainActor
    func testSourceControlAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let picker = app.descendants(matching: .any)["workspaceModePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["sourceControlWorkspace"].waitForExistence(timeout: 5))

        try app.performAccessibilityAudit(for: [.sufficientElementDescription]) { issue in
            let elementType = issue.element?.elementType
            return elementType == .group || elementType == .touchBar
        }
    }
}
