import XCTest
@testable import Flunner

final class WorkspaceStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testRecentProjectsAreDeduplicatedAndCapped() throws {
        let store = WorkspaceStore(directoryURL: temporaryDirectory)
        var snapshot = WorkspaceSnapshot()

        for index in 0..<12 {
            try store.upsert(RecentProject(path: "/tmp/project-\(index)"), in: &snapshot)
        }
        try store.upsert(RecentProject(path: "/tmp/project-5"), in: &snapshot)

        XCTAssertEqual(snapshot.recentProjects.count, WorkspaceStore.recentProjectLimit)
        XCTAssertEqual(snapshot.recentProjects.first?.path, "/tmp/project-5")
        XCTAssertEqual(snapshot.recentProjects.filter { $0.path == "/tmp/project-5" }.count, 1)
    }

    func testLegacyRunHistoryIsDroppedOnLoadAndSave() throws {
        let legacyJSON = """
        {
          "recentProjects" : [],
          "schemaVersion" : 2,
          "sessions" : [
            {
              "configurationName" : "Debug",
              "deviceId" : "device",
              "deviceName" : "Device",
              "endedAt" : "2026-08-11T00:00:02Z",
              "id" : "00000000-0000-0000-0000-000000000001",
              "outcome" : "ended",
              "projectName" : "Demo",
              "projectPath" : "/tmp/demo",
              "startedAt" : "2026-08-11T00:00:00Z"
            }
          ]
        }
        """
        try legacyJSON.write(
            to: temporaryDirectory.appendingPathComponent("workspace.json"),
            atomically: true,
            encoding: .utf8
        )

        let store = WorkspaceStore(directoryURL: temporaryDirectory)
        let snapshot = try store.load()
        try store.save(snapshot)

        let persisted = try String(
            contentsOf: temporaryDirectory.appendingPathComponent("workspace.json"),
            encoding: .utf8
        )
        XCTAssertFalse(persisted.contains("sessions"))
        XCTAssertEqual(snapshot.schemaVersion, WorkspaceSnapshot.currentSchemaVersion)
    }

    func testSnapshotRoundTripsAtomically() throws {
        let store = WorkspaceStore(directoryURL: temporaryDirectory)
        var snapshot = WorkspaceSnapshot()
        try store.upsert(RecentProject(path: "/tmp/sample"), in: &snapshot)

        let loaded = try store.load()

        XCTAssertEqual(loaded.schemaVersion, WorkspaceSnapshot.currentSchemaVersion)
        XCTAssertEqual(loaded.recentProjects.map(\.path), ["/tmp/sample"])
    }

    func testTerminalLayoutRoundTripsWithoutTerminalOutput() throws {
        let store = WorkspaceStore(directoryURL: temporaryDirectory)
        let firstTab = TerminalTabSnapshot(title: "Server")
        let secondTab = TerminalTabSnapshot(title: "Tests")
        let layout = TerminalWorkspaceSnapshot(
            isVisible: true,
            paneHeight: 312,
            tabs: [firstTab, secondTab],
            selectedTabID: secondTab.id
        )
        var snapshot = WorkspaceSnapshot(
            recentProjects: [RecentProject(path: "/tmp/sample", terminalWorkspace: layout)]
        )

        try store.save(snapshot)
        snapshot = try store.load()

        XCTAssertEqual(snapshot.recentProjects.first?.terminalWorkspace, layout)
        let persisted = try String(
            contentsOf: temporaryDirectory.appendingPathComponent("workspace.json"),
            encoding: .utf8
        )
        XCTAssertFalse(persisted.contains("scrollback"))
        XCTAssertFalse(persisted.contains("environment"))
    }

    func testVersionOneWorkspaceMigratesWithoutTerminalMetadata() throws {
        let legacyJSON = """
        {
          "recentProjects" : [
            {
              "displayName" : "Legacy",
              "lastOpenedAt" : "2026-08-11T00:00:00Z",
              "path" : "/tmp/legacy"
            }
          ],
          "schemaVersion" : 1,
          "sessions" : []
        }
        """
        try legacyJSON.write(
            to: temporaryDirectory.appendingPathComponent("workspace.json"),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try WorkspaceStore(directoryURL: temporaryDirectory).load()

        XCTAssertEqual(loaded.schemaVersion, WorkspaceSnapshot.currentSchemaVersion)
        XCTAssertEqual(loaded.recentProjects.first?.path, "/tmp/legacy")
        XCTAssertNil(loaded.recentProjects.first?.terminalWorkspace)
    }

    func testUpdatingProjectMetadataPreservesManualOrder() throws {
        let store = WorkspaceStore(directoryURL: temporaryDirectory)
        var snapshot = WorkspaceSnapshot()
        try store.upsert(RecentProject(path: "/tmp/one"), in: &snapshot)
        try store.upsert(RecentProject(path: "/tmp/two"), in: &snapshot)
        let originalOrder = snapshot.recentProjects.map(\.path)

        var updated = try XCTUnwrap(snapshot.recentProjects.last)
        updated.lastDeviceId = "updated-device"
        try store.updateProject(updated, in: &snapshot)

        XCTAssertEqual(snapshot.recentProjects.map(\.path), originalOrder)
        XCTAssertEqual(snapshot.recentProjects.last?.lastDeviceId, "updated-device")
    }
}
