import XCTest
@testable import Flugger

@MainActor
final class KeyboardShortcutStoreTests: XCTestCase {
    func testBindingsPersistAcrossStoreInstances() {
        let defaults = makeDefaults()
        let store = KeyboardShortcutStore(defaults: defaults)

        store.setKey(.g, for: .run)
        store.toggleModifier(.shift, for: .run)

        let reloaded = KeyboardShortcutStore(defaults: defaults)
        XCTAssertEqual(
            reloaded.binding(for: .run),
            WorkbenchShortcut(key: .g, modifiers: [.command, .shift])
        )
    }

    func testConflictingBindingIsRejected() {
        let store = KeyboardShortcutStore(defaults: makeDefaults())
        let originalRunBinding = store.binding(for: .run)

        store.setKey(.r, for: .run)

        XCTAssertEqual(store.binding(for: .run), originalRunBinding)
        XCTAssertEqual(store.validationMessage, "⌘R is already assigned to Hot Reload.")
    }

    func testShortcutMustKeepPrimaryModifier() {
        let store = KeyboardShortcutStore(defaults: makeDefaults())
        let originalRunBinding = store.binding(for: .run)

        store.toggleModifier(.command, for: .run)

        XCTAssertEqual(store.binding(for: .run), originalRunBinding)
        XCTAssertEqual(store.validationMessage, "A shortcut must include Command, Option, or Control.")
    }

    func testResetAllRestoresDefaults() {
        let store = KeyboardShortcutStore(defaults: makeDefaults())
        store.setKey(.g, for: .run)

        store.resetAll()

        XCTAssertEqual(store.binding(for: .run), WorkbenchAction.run.defaultShortcut)
        XCTAssertNil(store.validationMessage)
    }

    func testAppFontSizeShortcutsUseStandardBindings() {
        XCTAssertEqual(
            WorkbenchAction.increaseAppFontSize.defaultShortcut,
            WorkbenchShortcut(key: .plus, modifiers: [.command])
        )
        XCTAssertEqual(
            WorkbenchAction.decreaseAppFontSize.defaultShortcut,
            WorkbenchShortcut(key: .minus, modifiers: [.command])
        )
    }

    func testLogChannelShortcutsUsePlannedBindings() {
        XCTAssertEqual(
            WorkbenchAction.showConsole.defaultShortcut,
            WorkbenchShortcut(key: .one, modifiers: [.command, .shift])
        )
        XCTAssertEqual(
            WorkbenchAction.showOutput.defaultShortcut,
            WorkbenchShortcut(key: .two, modifiers: [.command, .shift])
        )
    }

    func testTerminalShortcutUsesControlGraveAccent() {
        XCTAssertEqual(
            WorkbenchAction.toggleTerminal.defaultShortcut,
            WorkbenchShortcut(key: .graveAccent, modifiers: [.control])
        )
        XCTAssertEqual(WorkbenchAction.toggleTerminal.defaultShortcut.displayName, "⌃`")
    }

    func testAppFontSizeChangesAreClamped() {
        XCTAssertEqual(AppFontSizing.increased(AppFontSizing.maximumSize), AppFontSizing.maximumSize)
        XCTAssertEqual(AppFontSizing.decreased(AppFontSizing.minimumSize), AppFontSizing.minimumSize)
        XCTAssertEqual(AppFontSizing.increased(AppFontSizing.defaultSize), AppFontSizing.defaultSize + 1)
        XCTAssertEqual(AppFontSizing.decreased(AppFontSizing.defaultSize), AppFontSizing.defaultSize - 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "KeyboardShortcutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
