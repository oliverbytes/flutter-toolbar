import XCTest
@testable import Flunner

@MainActor
final class WorkspaceProjectIsolationTests: XCTestCase {
    func testSwitchingProjectsPreservesOrderAndRestoresEachConsole() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerProjectIsolation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try makeFlutterProject(named: "First", under: root)
        let second = try makeFlutterProject(named: "Second", under: root)
        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: root.appendingPathComponent("Data", isDirectory: true)),
            daemon: FlutterDaemon(),
            startDaemon: false,
            restoreLastProject: false
        )

        try viewModel.openProject(at: first.path)
        viewModel.addLog("Only in First")
        try viewModel.openProject(at: second.path)
        viewModel.addLog("Only in Second")
        let originalOrder = viewModel.recentProjects.map(\.path)

        viewModel.selectWorkspace(.project(first.path))

        XCTAssertEqual(viewModel.recentProjects.map(\.path), originalOrder)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Only in First" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Only in Second" })

        viewModel.selectWorkspace(.project(second.path))

        XCTAssertEqual(viewModel.recentProjects.map(\.path), originalOrder)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Only in Second" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Only in First" })
    }

    func testProjectBuffersShareTheGlobalTenThousandLineLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerGlobalLogCap-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try makeFlutterProject(named: "First", under: root)
        let second = try makeFlutterProject(named: "Second", under: root)
        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: root.appendingPathComponent("Data", isDirectory: true)),
            daemon: FlutterDaemon(),
            startDaemon: false,
            restoreLastProject: false
        )

        try viewModel.openProject(at: first.path)
        viewModel.clearLogs()
        for index in 0..<6_000 { viewModel.addLog("First \(index)") }

        try viewModel.openProject(at: second.path)
        viewModel.selectLogChannel(.output)
        viewModel.clearLogs()
        for index in 0..<6_000 { viewModel.addLog("Second \(index)", channel: .output) }
        let secondCount = viewModel.logLines.count

        viewModel.selectWorkspace(.project(first.path))
        viewModel.selectLogChannel(.console)
        let firstCount = viewModel.logLines.count

        XCTAssertLessThanOrEqual(firstCount + secondCount, WorkspaceViewModel.maximumLogEntries)
        XCTAssertTrue(viewModel.logLines.contains { $0.text.contains("10,000 lines") })
    }

    func testSwitchingProjectsRestoresConsoleAndOutputIndependently() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerChannelIsolation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try makeFlutterProject(named: "First", under: root)
        let second = try makeFlutterProject(named: "Second", under: root)
        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: root.appendingPathComponent("Data", isDirectory: true)),
            daemon: FlutterDaemon(),
            startDaemon: false,
            restoreLastProject: false
        )

        try viewModel.openProject(at: first.path)
        viewModel.addLog("First console")
        viewModel.addLog("First output", channel: .output)

        try viewModel.openProject(at: second.path)
        viewModel.addLog("Second console")
        viewModel.addLog("Second output", channel: .output)

        viewModel.selectWorkspace(.project(first.path))
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "First console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Second console" })

        viewModel.selectLogChannel(.output)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "First output" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Second output" })

        viewModel.selectWorkspace(.project(second.path))
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Second output" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "First output" })

        viewModel.selectLogChannel(.console)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Second console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "First console" })
    }

    private func makeFlutterProject(named name: String, under root: URL) throws -> URL {
        let project = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "name: \(name.lowercased())\nflutter:\n".write(
            to: project.appendingPathComponent("pubspec.yaml"),
            atomically: true,
            encoding: .utf8
        )
        return project.resolvingSymlinksInPath()
    }
}
