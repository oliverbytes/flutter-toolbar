import XCTest
@testable import Flugger

@MainActor
final class MultiProjectRunnerTests: XCTestCase {
    func testEachProjectOwnsIndependentRunControlsAndHistory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FluggerMultiRunner-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try makeFlutterProject(named: "First", under: root)
        let second = try makeFlutterProject(named: "Second", under: root)
        let daemon = FlutterDaemon()
        var runners: [String: MockFlutterRunner] = [:]
        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: root.appendingPathComponent("Data", isDirectory: true)),
            daemon: daemon,
            startDaemon: false,
            restoreLastProject: false,
            runnerFactory: { projectPath, deviceID in
                let runner = MockFlutterRunner(projectPath: projectPath, deviceId: deviceID)
                runners[projectPath] = runner
                return runner
            }
        )
        daemon.devices = [testDevice]
        for _ in 0..<10 where viewModel.devices.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(viewModel.devices.map(\.id), [testDevice.id])

        try viewModel.openProject(at: first.path)
        viewModel.selectDevice(testDevice.id)
        viewModel.runApp()

        XCTAssertTrue(viewModel.isAppRunning)
        XCTAssertTrue(viewModel.isProjectRunning(first.path))

        try viewModel.openProject(at: second.path)
        viewModel.selectDevice(testDevice.id)

        XCTAssertFalse(viewModel.isAppRunning)
        XCTAssertTrue(viewModel.canRun)
        XCTAssertTrue(viewModel.isProjectRunning(first.path))

        viewModel.runApp()

        XCTAssertTrue(viewModel.isAppRunning)
        XCTAssertTrue(viewModel.isProjectRunning(second.path))
        XCTAssertEqual(runners.count, 2)

        viewModel.selectWorkspace(.project(first.path))
        viewModel.hotReload()
        viewModel.stopApp()

        XCTAssertEqual(runners[first.path]?.hotReloadCount, 1)
        XCTAssertEqual(runners[first.path]?.stopCount, 1)
        XCTAssertEqual(runners[second.path]?.stopCount, 0)
        XCTAssertFalse(viewModel.isProjectRunning(first.path))
        XCTAssertTrue(viewModel.isProjectRunning(second.path))
        XCTAssertEqual(viewModel.sessions.map(\.projectPath), [first.path])

        viewModel.selectWorkspace(.project(second.path))
        viewModel.stopApp()

        XCTAssertFalse(viewModel.hasRunningProjects)
        XCTAssertEqual(Set(viewModel.sessions.map(\.projectPath)), Set([first.path, second.path]))
        XCTAssertEqual(viewModel.sessions.count, 2)
    }

    private var testDevice: Device {
        Device(
            id: "test-device",
            name: "Test Mac",
            platform: "darwin-arm64",
            platformType: "macos",
            category: "desktop",
            emulator: false,
            emulatorId: nil,
            ephemeral: false
        )
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

@MainActor
private final class MockFlutterRunner: FlutterRunner {
    private(set) var stopCount = 0
    private(set) var hotReloadCount = 0

    override func start(with launchConfig: LaunchConfig? = nil) {
        appState = .starting
        status = "Starting app..."
        appState = .running
        status = "App running"
        onLogOutput?("Mock app running", .info)
    }

    override func stop() {
        stopCount += 1
        appState = .stopping
        status = "Stopping..."
        appState = .idle
        status = "App stopped"
        onCompletion?(.stoppedByUser)
    }

    override func hotReload() {
        hotReloadCount += 1
        status = "Hot reloading..."
    }
}
