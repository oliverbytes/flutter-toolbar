import XCTest
@testable import Flunner

@MainActor
final class MultiProjectRunnerTests: XCTestCase {
    func testEachProjectOwnsIndependentRunControlsAndHistory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerMultiRunner-\(UUID().uuidString)", isDirectory: true)
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
        viewModel.selectLogChannel(.output)
        viewModel.runApp()

        XCTAssertTrue(viewModel.isAppRunning)
        XCTAssertTrue(viewModel.isProjectRunning(first.path))
        XCTAssertEqual(viewModel.selectedLogChannel, .console)
        XCTAssertEqual(viewModel.selection, .project(first.path))

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
        viewModel.selectLogChannel(.output)
        viewModel.hotReload()

        XCTAssertEqual(viewModel.selectedLogChannel, .console)
        XCTAssertEqual(viewModel.selection, .project(first.path))

        viewModel.selectLogChannel(.output)
        viewModel.selection = .console
        viewModel.hotRestart()

        XCTAssertEqual(viewModel.selectedLogChannel, .console)
        XCTAssertEqual(viewModel.selection, .project(first.path))

        viewModel.stopApp()

        XCTAssertEqual(runners[first.path]?.hotReloadCount, 1)
        XCTAssertEqual(runners[first.path]?.hotRestartCount, 1)
        XCTAssertEqual(runners[first.path]?.stopCount, 1)
        XCTAssertEqual(runners[second.path]?.stopCount, 0)
        XCTAssertFalse(viewModel.isProjectRunning(first.path))
        XCTAssertTrue(viewModel.isProjectRunning(second.path))

        viewModel.selectWorkspace(.project(second.path))
        viewModel.stopApp()

        XCTAssertFalse(viewModel.hasRunningProjects)
    }

    func testConcurrentRunsOnDifferentDevicesKeepSeparateLogsAndControls() async throws {
        let context = try await makeDualDeviceContext(named: "ConcurrentDevices")
        defer { try? FileManager.default.removeItem(at: context.root) }
        let viewModel = context.viewModel

        viewModel.selectDevice(iosDevice.id)
        viewModel.runApp()
        viewModel.addLog("iOS console")
        viewModel.addLog("iOS output", channel: .output)

        XCTAssertEqual(viewModel.liveRuns(for: context.project.path).count, 1)
        XCTAssertFalse(viewModel.canRun)
        XCTAssertTrue(viewModel.canStopSelectedRun)
        XCTAssertTrue(viewModel.canControlSelectedRun)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "iOS console" })

        viewModel.selectDevice(androidDevice.id)

        XCTAssertTrue(viewModel.canRun)
        XCTAssertTrue(viewModel.canPubGet)
        XCTAssertFalse(viewModel.canCleanAndPubGet)
        XCTAssertFalse(viewModel.canStopSelectedRun)
        XCTAssertFalse(viewModel.canControlSelectedRun)
        XCTAssertNil(viewModel.selectedLiveRun)
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "iOS console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Mock app running" })

        viewModel.selectLogChannel(.output)
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "iOS output" })
        viewModel.selectLogChannel(.console)

        viewModel.runApp()
        viewModel.addLog("Android console")
        viewModel.addLog("Android output", channel: .output)

        XCTAssertEqual(viewModel.liveRuns(for: context.project.path).count, 2)
        XCTAssertFalse(viewModel.canRun)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Android console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "iOS console" })

        viewModel.selectLogChannel(.output)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Android output" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "iOS output" })
        viewModel.selectLogChannel(.console)

        viewModel.stopApp()

        XCTAssertEqual(context.runners.runners[androidDevice.id]?.stopCount, 1)
        XCTAssertEqual(context.runners.runners[iosDevice.id]?.stopCount, 0)
        XCTAssertTrue(viewModel.isProjectRunning(context.project.path))
        XCTAssertTrue(viewModel.canRun)
        XCTAssertNil(viewModel.selectedLiveRun)

        viewModel.selectDevice(iosDevice.id)
        XCTAssertTrue(viewModel.canStopSelectedRun)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "iOS console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Android console" })

        viewModel.stopApp()
        XCTAssertEqual(context.runners.runners[iosDevice.id]?.stopCount, 1)
        XCTAssertFalse(viewModel.hasRunningProjects)
    }

    func testSelectLiveRunRestoresDeviceConfigLogsAndControls() async throws {
        let context = try await makeDualDeviceContext(named: "SelectLiveRun")
        defer { try? FileManager.default.removeItem(at: context.root) }
        let viewModel = context.viewModel

        viewModel.selectDevice(iosDevice.id)
        viewModel.selectConfiguration("Debug")
        viewModel.runApp()
        viewModel.addLog("iOS console")

        viewModel.selectDevice(androidDevice.id)
        viewModel.selectConfiguration("Profile")
        viewModel.runApp()
        viewModel.addLog("Android console")

        XCTAssertEqual(viewModel.selectedDeviceId, androidDevice.id)
        XCTAssertEqual(viewModel.selectedLaunchConfigName, "Profile")
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Android console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "iOS console" })

        let iosRun = try XCTUnwrap(viewModel.liveRun(forDeviceId: iosDevice.id))
        viewModel.selectLiveRun(iosRun.id)

        XCTAssertEqual(viewModel.selectedLiveRunID, iosRun.id)
        XCTAssertEqual(viewModel.selectedDeviceId, iosDevice.id)
        XCTAssertEqual(viewModel.selectedLaunchConfigName, "Debug")
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "iOS console" })
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Android console" })
        XCTAssertFalse(viewModel.canRun)
        XCTAssertTrue(viewModel.canStopSelectedRun)
        XCTAssertTrue(viewModel.canControlSelectedRun)
        XCTAssertTrue(viewModel.canPubGet)
        XCTAssertFalse(viewModel.canCleanAndPubGet)
    }

    func testHotRestartOnOneDeviceDoesNotWipeTheOther() async throws {
        let context = try await makeDualDeviceContext(named: "HotRestartIsolation")
        defer { try? FileManager.default.removeItem(at: context.root) }
        let viewModel = context.viewModel

        viewModel.selectDevice(iosDevice.id)
        viewModel.runApp()
        viewModel.addLog("keep iOS console")
        viewModel.addLog("keep iOS output", channel: .output)

        viewModel.selectDevice(androidDevice.id)
        viewModel.runApp()
        viewModel.addLog("stale Android console")
        viewModel.addLog("stale Android output", channel: .output)
        viewModel.hotRestart()

        XCTAssertEqual(context.runners.runners[androidDevice.id]?.hotRestartCount, 1)
        XCTAssertEqual(context.runners.runners[iosDevice.id]?.hotRestartCount, 0)
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "stale Android console" })
        viewModel.selectLogChannel(.output)
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "stale Android output" })

        viewModel.selectDevice(iosDevice.id)
        viewModel.selectLogChannel(.console)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "keep iOS console" })
        viewModel.selectLogChannel(.output)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "keep iOS output" })
    }

    func testRunAppClearsOnlySelectedDeviceLogs() async throws {
        let context = try await makeDualDeviceContext(named: "ClearLogsOnRun")
        defer { try? FileManager.default.removeItem(at: context.root) }
        let viewModel = context.viewModel

        viewModel.selectDevice(iosDevice.id)
        viewModel.addLog("keep iOS console")
        viewModel.addLog("keep iOS output", channel: .output)

        viewModel.selectDevice(androidDevice.id)
        viewModel.addLog("stale Android console")
        viewModel.addLog("stale Android output", channel: .output)
        viewModel.runApp()

        XCTAssertFalse(viewModel.logLines.contains { $0.text == "stale Android console" })
        viewModel.selectLogChannel(.output)
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "stale Android output" })

        viewModel.selectDevice(iosDevice.id)
        viewModel.selectLogChannel(.console)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "keep iOS console" })
        viewModel.selectLogChannel(.output)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "keep iOS output" })
        viewModel.selectLogChannel(.console)
        XCTAssertEqual(viewModel.selectedLogChannel, .console)
    }

    func testHotRestartClearsConsoleAndOutputLogs() async throws {
        let context = try await makeDualDeviceContext(named: "ClearLogsOnHotRestart")
        defer { try? FileManager.default.removeItem(at: context.root) }
        let viewModel = context.viewModel

        viewModel.selectDevice(testDevice.id)
        viewModel.runApp()

        viewModel.addLog("stale console after run")
        viewModel.addLog("stale output after run", channel: .output)

        viewModel.hotRestart()

        XCTAssertFalse(viewModel.logLines.contains { $0.text == "stale console after run" })
        viewModel.selectLogChannel(.output)
        XCTAssertFalse(viewModel.logLines.contains { $0.text == "stale output after run" })
        viewModel.selectLogChannel(.console)
        XCTAssertEqual(viewModel.selectedLogChannel, .console)
    }

    func testClearLogsOnlyClearsSelectedDeviceAndChannel() async throws {
        let context = try await makeDualDeviceContext(named: "ClearLogsScope")
        defer { try? FileManager.default.removeItem(at: context.root) }
        let viewModel = context.viewModel

        viewModel.selectDevice(iosDevice.id)
        viewModel.addLog("iOS console")
        viewModel.addLog("iOS output", channel: .output)

        viewModel.selectDevice(androidDevice.id)
        viewModel.addLog("Android console")
        viewModel.addLog("Android output", channel: .output)
        viewModel.clearLogs()

        XCTAssertFalse(viewModel.logLines.contains { $0.text == "Android console" })
        viewModel.selectLogChannel(.output)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "Android output" })

        viewModel.selectDevice(iosDevice.id)
        viewModel.selectLogChannel(.console)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "iOS console" })
        viewModel.selectLogChannel(.output)
        XCTAssertTrue(viewModel.logLines.contains { $0.text == "iOS output" })
    }

    private var testDevice: Device { iosDevice }

    private var iosDevice: Device {
        Device(
            id: "ios-device",
            name: "iPhone",
            platform: "ios",
            platformType: "iphoneos",
            category: "mobile",
            emulator: true,
            emulatorId: "iphone-sim",
            ephemeral: true
        )
    }

    private var androidDevice: Device {
        Device(
            id: "android-device",
            name: "Pixel",
            platform: "android",
            platformType: "android",
            category: "mobile",
            emulator: true,
            emulatorId: "pixel-emu",
            ephemeral: true
        )
    }

    private func makeDualDeviceContext(named name: String) async throws -> (
        root: URL,
        project: URL,
        viewModel: WorkspaceViewModel,
        runners: RunnerMap
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Flunner\(name)-\(UUID().uuidString)", isDirectory: true)
        let project = try makeFlutterProject(named: name, under: root)
        let daemon = FlutterDaemon()
        let runners = RunnerMap()
        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: root.appendingPathComponent("Data", isDirectory: true)),
            daemon: daemon,
            startDaemon: false,
            restoreLastProject: false,
            runnerFactory: { projectPath, deviceID in
                let runner = MockFlutterRunner(projectPath: projectPath, deviceId: deviceID)
                runners.runners[deviceID] = runner
                return runner
            }
        )
        daemon.devices = [iosDevice, androidDevice]
        for _ in 0..<10 where viewModel.devices.count < 2 {
            await Task.yield()
        }
        XCTAssertEqual(Set(viewModel.devices.map(\.id)), [iosDevice.id, androidDevice.id])

        try viewModel.openProject(at: project.path)
        return (root, project, viewModel, runners)
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
private final class RunnerMap {
    var runners: [String: MockFlutterRunner] = [:]
}

@MainActor
private final class MockFlutterRunner: FlutterRunner {
    private(set) var stopCount = 0
    private(set) var hotReloadCount = 0
    private(set) var hotRestartCount = 0

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

    override func hotRestart() {
        hotRestartCount += 1
        status = "Hot restarting..."
    }
}
