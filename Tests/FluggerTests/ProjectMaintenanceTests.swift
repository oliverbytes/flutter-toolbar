import XCTest
@testable import Flugger

@MainActor
final class ProjectMaintenanceTests: XCTestCase {
    func testCleanAndPubGetRequiresConfirmationThenRunsBothCommands() throws {
        let legacyPreferences = LegacyPreferencesSnapshot()
        let context = try makeContext()
        defer {
            legacyPreferences.restore()
            try? FileManager.default.removeItem(at: context.root)
        }

        context.viewModel.requestCleanAndPubGet()

        XCTAssertTrue(context.viewModel.isCleanConfirmationPresented)
        XCTAssertTrue(context.maintenance.operations.isEmpty)

        context.viewModel.cleanAndPubGet()

        XCTAssertFalse(context.viewModel.isCleanConfirmationPresented)
        XCTAssertEqual(context.maintenance.operations, [.cleanAndPubGet])
        XCTAssertFalse(context.viewModel.canMaintainProject)
        XCTAssertFalse(context.viewModel.canRun)

        context.maintenance.finish(.succeeded)

        XCTAssertTrue(context.viewModel.canMaintainProject)
        XCTAssertEqual(context.viewModel.status, "Clean + Pub Get completed")
        XCTAssertTrue(context.viewModel.logLines.contains { $0.text == "Clean + Pub Get completed" })
    }

    func testPubGetRunsWithoutConfirmation() throws {
        let legacyPreferences = LegacyPreferencesSnapshot()
        let context = try makeContext()
        defer {
            legacyPreferences.restore()
            try? FileManager.default.removeItem(at: context.root)
        }

        context.viewModel.selection = .session(UUID())
        context.viewModel.pubGet()

        XCTAssertEqual(context.maintenance.operations, [.pubGet])
        XCTAssertFalse(context.viewModel.isCleanConfirmationPresented)
        XCTAssertEqual(context.viewModel.selectedLogChannel, .output)
        XCTAssertEqual(context.viewModel.selection, .project(context.viewModel.projectPath ?? ""))
    }

    func testMaintenanceStreamsOnlyToOutputAndLeavesItSelected() throws {
        let legacyPreferences = LegacyPreferencesSnapshot()
        let context = try makeContext()
        defer {
            legacyPreferences.restore()
            try? FileManager.default.removeItem(at: context.root)
        }

        context.viewModel.addLog("Runner console line")
        context.viewModel.pubGet()
        context.maintenance.emit("Resolving dependencies…", type: .command)
        context.maintenance.emit("Downloaded package", type: .info)
        context.maintenance.finish(.succeeded)

        XCTAssertEqual(context.viewModel.selectedLogChannel, .output)
        XCTAssertTrue(context.viewModel.logLines.contains { $0.text.contains("Pub Get — Demo —") })
        XCTAssertTrue(context.viewModel.logLines.contains { $0.text == "Resolving dependencies…" })
        XCTAssertTrue(context.viewModel.logLines.contains { $0.text == "Downloaded package" })
        XCTAssertTrue(context.viewModel.logLines.contains { $0.text == "Pub Get completed" })

        context.viewModel.selectLogChannel(.console)

        XCTAssertTrue(context.viewModel.logLines.contains { $0.text == "Runner console line" })
        XCTAssertFalse(context.viewModel.logLines.contains { $0.text == "Resolving dependencies…" })
        XCTAssertFalse(context.viewModel.logLines.contains { $0.text == "Pub Get completed" })
    }

    func testRepeatedRunsAppendHeadersAndFailureDetails() throws {
        let legacyPreferences = LegacyPreferencesSnapshot()
        let context = try makeContext()
        defer {
            legacyPreferences.restore()
            try? FileManager.default.removeItem(at: context.root)
        }

        context.viewModel.pubGet()
        context.maintenance.finish(.succeeded)
        context.viewModel.pubGet()
        context.maintenance.finish(.failed(command: "flutter pub get", exitCode: 65))

        XCTAssertEqual(
            context.viewModel.logLines.filter { $0.text.contains("Pub Get — Demo —") }.count,
            2
        )
        XCTAssertTrue(context.viewModel.logLines.contains {
            $0.text == "flutter pub get exited with code 65" && $0.type == .error
        })
        XCTAssertEqual(context.viewModel.status, "Pub Get failed")
        XCTAssertEqual(context.viewModel.selectedLogChannel, .output)
    }

    func testLaunchFailureIsVisibleInOutput() throws {
        let legacyPreferences = LegacyPreferencesSnapshot()
        let context = try makeContext()
        defer {
            legacyPreferences.restore()
            try? FileManager.default.removeItem(at: context.root)
        }

        context.viewModel.cleanAndPubGet()
        context.maintenance.finish(.launchFailed("flutter executable not found"))

        XCTAssertEqual(context.viewModel.status, "Could not start Clean + Pub Get")
        XCTAssertTrue(context.viewModel.logLines.contains {
            $0.text == "flutter executable not found" && $0.type == .error
        })
    }

    func testSearchAndFiltersAreIndependentPerChannel() throws {
        let legacyPreferences = LegacyPreferencesSnapshot()
        let context = try makeContext()
        defer {
            legacyPreferences.restore()
            try? FileManager.default.removeItem(at: context.root)
        }

        context.viewModel.searchText = "console query"
        context.viewModel.toggleFilter(.error)
        context.viewModel.selectLogChannel(.output)
        context.viewModel.searchText = "output query"
        context.viewModel.toggleFilter(.info)

        XCTAssertEqual(context.viewModel.searchText, "output query")
        XCTAssertFalse(context.viewModel.enabledLogTypes.contains(.info))
        XCTAssertTrue(context.viewModel.enabledLogTypes.contains(.error))

        context.viewModel.selectLogChannel(.console)

        XCTAssertEqual(context.viewModel.searchText, "console query")
        XCTAssertTrue(context.viewModel.enabledLogTypes.contains(.info))
        XCTAssertFalse(context.viewModel.enabledLogTypes.contains(.error))
    }

    func testMaintenanceOperationCommandSequences() {
        XCTAssertEqual(FlutterProjectMaintenanceOperation.pubGet.commands, [["pub", "get"]])
        XCTAssertEqual(
            FlutterProjectMaintenanceOperation.cleanAndPubGet.commands,
            [["clean"], ["pub", "get"]]
        )
    }

    private func makeContext() throws -> (
        root: URL,
        viewModel: WorkspaceViewModel,
        maintenance: MockProjectMaintenance
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FluggerMaintenance-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("Demo", isDirectory: true)
        let dataDirectory = root.appendingPathComponent("Data", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "name: demo\nflutter:\n".write(
            to: project.appendingPathComponent("pubspec.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let maintenance = MockProjectMaintenance()
        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: dataDirectory),
            daemon: FlutterDaemon(),
            projectMaintenance: maintenance,
            startDaemon: false,
            restoreLastProject: false
        )
        try viewModel.openProject(at: project.path)
        return (root, viewModel, maintenance)
    }
}

@MainActor
private struct LegacyPreferencesSnapshot {
    let projectPath = UserDefaultsStore.shared.lastProjectPath
    let deviceID = UserDefaultsStore.shared.lastDeviceId
    let configurationName = UserDefaultsStore.shared.lastLaunchConfigName

    func restore() {
        UserDefaultsStore.shared.lastProjectPath = projectPath
        UserDefaultsStore.shared.lastDeviceId = deviceID
        UserDefaultsStore.shared.lastLaunchConfigName = configurationName
    }
}

@MainActor
private final class MockProjectMaintenance: FlutterProjectMaintaining {
    private(set) var operations: [FlutterProjectMaintenanceOperation] = []
    private var onOutput: ((String, LogEntryType) -> Void)?
    private var completion: ((FlutterProjectMaintenanceOutcome) -> Void)?

    func run(
        _ operation: FlutterProjectMaintenanceOperation,
        projectPath _: String,
        onOutput: @escaping (String, LogEntryType) -> Void,
        completion: @escaping (FlutterProjectMaintenanceOutcome) -> Void
    ) -> Bool {
        operations.append(operation)
        self.onOutput = onOutput
        self.completion = completion
        onOutput(operation.displayName, .command)
        return true
    }

    func emit(_ message: String, type: LogEntryType) {
        onOutput?(message, type)
    }

    func finish(_ outcome: FlutterProjectMaintenanceOutcome) {
        let completion = completion
        onOutput = nil
        self.completion = nil
        completion?(outcome)
    }
}
