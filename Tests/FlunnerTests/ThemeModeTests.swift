import XCTest
@testable import Flunner

final class ThemeModeTests: XCTestCase {
    func testNextCyclesThroughEveryTheme() {
        XCTAssertEqual(ThemeMode.system.next, .light)
        XCTAssertEqual(ThemeMode.light.next, .dark)
        XCTAssertEqual(ThemeMode.dark.next, .system)
    }
}
