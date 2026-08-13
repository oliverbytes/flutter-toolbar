import AppKit
import XCTest
@testable import Flunner

@MainActor
final class TerminalWorkspaceManagerTests: XCTestCase {
    func testToggleCreatesFirstTabAndClosingLastTabHidesPane() throws {
        let factory = FakeTerminalSessionFactory()
        let manager = TerminalWorkspaceManager(sessionFactory: factory)
        var persisted: [String: TerminalWorkspaceSnapshot] = [:]
        manager.onSnapshotChange = { persisted[$0] = $1 }

        manager.toggle(for: "/tmp/project")

        var state = manager.snapshot(for: "/tmp/project")
        XCTAssertTrue(state.isVisible)
        XCTAssertEqual(state.tabs.map(\.title), ["Terminal 1"])
        XCTAssertEqual(factory.sessions.count, 1)
        XCTAssertEqual(persisted["/tmp/project"], state)

        let tabID = try XCTUnwrap(state.selectedTabID)
        manager.closeTab(tabID, in: "/tmp/project")

        state = manager.snapshot(for: "/tmp/project")
        XCTAssertFalse(state.isVisible)
        XCTAssertTrue(state.tabs.isEmpty)
        XCTAssertNil(state.selectedTabID)
        XCTAssertEqual(factory.sessions[tabID]?.terminateCount, 1)
    }

    func testMultipleTabsSelectAdjacentTabAndPersistDynamicTitle() throws {
        let factory = FakeTerminalSessionFactory()
        let manager = TerminalWorkspaceManager(sessionFactory: factory)
        manager.toggle(for: "/tmp/project")
        let firstID = try XCTUnwrap(manager.selectedTabID(for: "/tmp/project"))
        manager.addTab(to: "/tmp/project")
        let secondID = try XCTUnwrap(manager.selectedTabID(for: "/tmp/project"))

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(manager.tabs(for: "/tmp/project").map(\.title), ["Terminal 1", "Terminal 2"])

        factory.sessions[secondID]?.emitTitle("project — zsh")
        XCTAssertEqual(manager.tabs(for: "/tmp/project").last?.title, "project — zsh")

        manager.closeTab(secondID, in: "/tmp/project")
        XCTAssertEqual(manager.selectedTabID(for: "/tmp/project"), firstID)
        XCTAssertTrue(manager.isVisible(for: "/tmp/project"))
    }

    func testProjectsKeepIndependentTabsAndRemovingOneTerminatesOnlyItsSessions() {
        let factory = FakeTerminalSessionFactory()
        let manager = TerminalWorkspaceManager(sessionFactory: factory)
        manager.toggle(for: "/tmp/one")
        manager.addTab(to: "/tmp/one")
        manager.toggle(for: "/tmp/two")

        let firstProjectIDs = Set(manager.tabs(for: "/tmp/one").map(\.id))
        let secondProjectIDs = Set(manager.tabs(for: "/tmp/two").map(\.id))
        manager.removeProject("/tmp/one")

        XCTAssertTrue(manager.tabs(for: "/tmp/one").isEmpty)
        XCTAssertEqual(manager.tabs(for: "/tmp/two").count, 1)
        XCTAssertTrue(firstProjectIDs.allSatisfy { factory.sessions[$0]?.terminateCount == 1 })
        XCTAssertTrue(secondProjectIDs.allSatisfy { factory.sessions[$0]?.terminateCount == 0 })
    }

    func testRestoredLayoutStartsFreshSessionsLazily() throws {
        let firstID = UUID()
        let secondID = UUID()
        let restored = TerminalWorkspaceSnapshot(
            isVisible: true,
            paneHeight: 340,
            tabs: [
                TerminalTabSnapshot(id: firstID, title: "Server"),
                TerminalTabSnapshot(id: secondID, title: "Tests"),
            ],
            selectedTabID: secondID
        )
        let project = RecentProject(path: "/tmp/project", terminalWorkspace: restored)
        let factory = FakeTerminalSessionFactory()
        let manager = TerminalWorkspaceManager(projects: [project], sessionFactory: factory)
        var expected = restored
        expected.isVisible = false

        XCTAssertTrue(factory.sessions.isEmpty)
        XCTAssertEqual(manager.snapshot(for: project.path), expected)

        manager.activateProject(project.path)

        XCTAssertEqual(Set(factory.sessions.keys), [firstID, secondID])
        XCTAssertEqual(manager.selectedTabID(for: project.path), secondID)
        XCTAssertEqual(manager.snapshot(for: project.path).paneHeight, 340)
        XCTAssertEqual(manager.snapshot(for: project.path).isVisible, false)
    }

    func testShellExitClosesTabAndFinalExitHidesPane() throws {
        let factory = FakeTerminalSessionFactory()
        let manager = TerminalWorkspaceManager(sessionFactory: factory)
        manager.toggle(for: "/tmp/project")
        let tabID = try XCTUnwrap(manager.selectedTabID(for: "/tmp/project"))

        factory.sessions[tabID]?.finish(exitCode: 0)

        XCTAssertFalse(manager.isVisible(for: "/tmp/project"))
        XCTAssertTrue(manager.tabs(for: "/tmp/project").isEmpty)
        XCTAssertEqual(factory.sessions[tabID]?.terminateCount, 0)
    }
}

@MainActor
private final class FakeTerminalSessionFactory: TerminalSessionCreating {
    private(set) var sessions: [UUID: FakeTerminalSession] = [:]

    func makeSession(
        id: UUID,
        projectPath: String,
        titleChanged: @escaping (String) -> Void,
        terminated: @escaping (Int32?) -> Void
    ) -> any TerminalSession {
        let session = FakeTerminalSession(
            titleChanged: titleChanged,
            terminated: terminated
        )
        sessions[id] = session
        return session
    }
}

@MainActor
private final class FakeTerminalSession: TerminalSession {
    let view = NSView()
    private(set) var terminateCount = 0

    private let titleChanged: (String) -> Void
    private let terminated: (Int32?) -> Void

    init(titleChanged: @escaping (String) -> Void, terminated: @escaping (Int32?) -> Void) {
        self.titleChanged = titleChanged
        self.terminated = terminated
    }

    func applyAppearance(fontSize: CGFloat, foreground: NSColor, background: NSColor, caret: NSColor) { }
    func focus() { }
    func terminate() { terminateCount += 1 }
    func sendText(_ text: String) { }
    func emitTitle(_ title: String) { titleChanged(title) }
    func finish(exitCode: Int32?) { terminated(exitCode) }
}
