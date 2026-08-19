import XCTest
@testable import Flunner

final class ConsoleLogToolsTests: XCTestCase {
    private let entries = [
        LogEntry(text: "Flutter run started", type: .command, timestamp: Date(timeIntervalSince1970: 1)),
        LogEntry(text: "Connected to device", type: .info, timestamp: Date(timeIntervalSince1970: 2)),
        LogEntry(text: "Build ERROR in widget", type: .error, timestamp: Date(timeIntervalSince1970: 3)),
    ]

    func testFilterCombinesTypeAndCaseInsensitiveSearch() {
        let result = ConsoleLogTools.filter(entries, query: "error", enabledTypes: [.error, .info])
        XCTAssertEqual(result.map(\.text), ["Build ERROR in widget"])
    }

    func testEmptyTypeSelectionShowsAllRows() {
        let result = ConsoleLogTools.filter(entries, query: "", enabledTypes: [])
        XCTAssertEqual(result.map(\.text), entries.map(\.text))
    }

    func testEmptyTypeSelectionStillHonorsSearch() {
        let result = ConsoleLogTools.filter(entries, query: "connected", enabledTypes: [])
        XCTAssertEqual(result.map(\.text), ["Connected to device"])
    }

    func testExportIncludesTimestampTypeAndMessage() {
        let exported = ConsoleLogTools.exportText([entries[2]])
        XCTAssertTrue(exported.contains("[ERROR]"))
        XCTAssertTrue(exported.contains("Build ERROR in widget"))
    }

    func testFlutterTagFilterKeepsOnlyMatchingLines() {
        let mixed = [
            LogEntry(text: "I/flutter (12345): hello", type: .info),
            LogEntry(text: "D/EGL_emulation: eglMakeCurrent", type: .info),
            LogEntry(text: "Another I/flutter line", type: .error),
            LogEntry(text: "Flutter run started", type: .command),
        ]

        let result = ConsoleLogTools.filter(
            mixed,
            query: "",
            enabledTypes: [],
            requiresFlutterTag: true
        )

        XCTAssertEqual(result.map(\.text), [
            "I/flutter (12345): hello",
            "Another I/flutter line",
        ])
    }

    func testFlutterTagFilterIsOffByDefaultInFilterAPI() {
        let mixed = [
            LogEntry(text: "I/flutter (12345): hello", type: .info),
            LogEntry(text: "D/EGL_emulation: eglMakeCurrent", type: .info),
        ]

        let result = ConsoleLogTools.filter(mixed, query: "", enabledTypes: [])
        XCTAssertEqual(result.map(\.text), mixed.map(\.text))
    }

    @MainActor
    func testFlutterConsoleFilterDefaultsOffAndOnlyAppliesToConsole() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerFlutterFilter-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: directory),
            daemon: FlutterDaemon(),
            startDaemon: false,
            restoreLastProject: false
        )
        viewModel.addLog("I/flutter (1): keep")
        viewModel.addLog("system noise")
        viewModel.addLog("I/flutter (1): output keep", channel: .output)
        viewModel.addLog("output noise", channel: .output)

        XCTAssertFalse(viewModel.isFlutterConsoleFilterEnabled)
        XCTAssertEqual(viewModel.filteredLogs.map(\.text), [
            "I/flutter (1): keep",
            "system noise",
        ])

        viewModel.toggleFlutterConsoleFilter()
        XCTAssertTrue(viewModel.isFlutterConsoleFilterEnabled)
        XCTAssertEqual(viewModel.filteredLogs.map(\.text), ["I/flutter (1): keep"])

        viewModel.selectLogChannel(.output)
        XCTAssertEqual(viewModel.filteredLogs.map(\.text), [
            "I/flutter (1): output keep",
            "output noise",
        ])
    }

    @MainActor
    func testWorkspaceCapsInMemoryLogBuffer() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerLogCap-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let viewModel = WorkspaceViewModel(
            store: WorkspaceStore(directoryURL: directory),
            daemon: FlutterDaemon(),
            startDaemon: false,
            restoreLastProject: false
        )
        for index in 0..<(WorkspaceViewModel.maximumLogEntries + 25) {
            viewModel.addLog("Line \(index)")
        }

        XCTAssertEqual(viewModel.logLines.count, WorkspaceViewModel.maximumLogEntries)
        XCTAssertTrue(viewModel.logLines.contains { $0.text.contains("10,000 lines") })
    }
}
