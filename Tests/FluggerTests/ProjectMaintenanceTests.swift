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

        context.viewModel.pubGet()

        XCTAssertEqual(context.maintenance.operations, [.pubGet])
        XCTAssertFalse(context.viewModel.isCleanConfirmationPresented)
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
    private var completion: ((FlutterProjectMaintenanceOutcome) -> Void)?

    func run(
        _ operation: FlutterProjectMaintenanceOperation,
        projectPath _: String,
        onOutput: @escaping (String, LogEntryType) -> Void,
        completion: @escaping (FlutterProjectMaintenanceOutcome) -> Void
    ) -> Bool {
        operations.append(operation)
        self.completion = completion
        onOutput(operation.displayName, .command)
        return true
    }

    func finish(_ outcome: FlutterProjectMaintenanceOutcome) {
        let completion = completion
        self.completion = nil
        completion?(outcome)
    }
}
