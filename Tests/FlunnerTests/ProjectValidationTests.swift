import XCTest
@testable import Flunner

final class ProjectValidationTests: XCTestCase {
    @MainActor
    func testMissingFolderIsRejected() {
        XCTAssertThrowsError(try WorkspaceViewModel.validateProject(at: "/tmp/flugger-does-not-exist")) { error in
            XCTAssertEqual(error as? WorkspaceValidationError, .missingDirectory)
        }
    }

    @MainActor
    func testFolderWithoutPubspecIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try WorkspaceViewModel.validateProject(at: directory.path)) { error in
            XCTAssertEqual(error as? WorkspaceValidationError, .missingPubspec)
        }
    }
}
