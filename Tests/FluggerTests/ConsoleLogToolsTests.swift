import XCTest
@testable import Flugger

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

    func testEmptyTypeSelectionReturnsNoRows() {
        XCTAssertTrue(ConsoleLogTools.filter(entries, query: "", enabledTypes: []).isEmpty)
    }

    func testExportIncludesTimestampTypeAndMessage() {
        let exported = ConsoleLogTools.exportText([entries[2]])
        XCTAssertTrue(exported.contains("[ERROR]"))
        XCTAssertTrue(exported.contains("Build ERROR in widget"))
    }

    @MainActor
    func testWorkspaceCapsInMemoryLogBuffer() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FluggerLogCap-\(UUID().uuidString)", isDirectory: true)
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
