import XCTest
@testable import Flugger

final class ThemeModeTests: XCTestCase {
    func testNextCyclesThroughEveryTheme() {
        XCTAssertEqual(ThemeMode.system.next, .light)
        XCTAssertEqual(ThemeMode.light.next, .dark)
        XCTAssertEqual(ThemeMode.dark.next, .system)
    }
}
