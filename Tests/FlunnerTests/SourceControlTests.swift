import Foundation
import Testing
@testable import Flunner

@Suite("Git status parsing")
struct GitStatusParserTests {
    @Test("Parses branch tracking, ordinary, renamed, conflicted, and untracked records")
    func parsesPorcelainV2() throws {
        let input = [
            "# branch.oid 1234567890",
            "# branch.head feature/source-control",
            "# branch.upstream origin/feature/source-control",
            "# branch.ab +2 -3",
            "1 M. N... 100644 100644 100644 aaaaaaa bbbbbbb Sources/App.swift",
            "2 R. N... 100644 100644 100644 ccccccc ddddddd R100 Sources/New.swift",
            "Sources/Old.swift",
            "u UU N... 100644 100644 100644 100644 aaaaaaa bbbbbbb ccccccc conflicted.txt",
            "? notes with spaces.md",
        ].joined(separator: "\0") + "\0"

        let result = GitStatusParser.parse(Data(input.utf8))

        #expect(result.branch == "feature/source-control")
        #expect(result.upstream == "origin/feature/source-control")
        #expect(result.ahead == 2)
        #expect(result.behind == 3)
        #expect(result.files.count == 4)

        let renamed = try #require(result.files.first { $0.path == "Sources/New.swift" })
        #expect(renamed.originalPath == "Sources/Old.swift")
        #expect(renamed.kind == .renamed)
        #expect(renamed.hasStagedChanges)

        let conflict = try #require(result.files.first { $0.path == "conflicted.txt" })
        #expect(conflict.isConflicted)

        let untracked = try #require(result.files.first { $0.path == "notes with spaces.md" })
        #expect(untracked.isUntracked)
    }

    @Test("Parses unified diff line numbers and kinds")
    func parsesUnifiedDiff() throws {
        let diff = GitDiff.parse(
            title: "Example.swift",
            text: "@@ -4,2 +4,3 @@\n context\n-old\n+new\n+another"
        )

        #expect(diff.lines.count == 5)
        #expect(diff.lines[1].oldLine == 4)
        #expect(diff.lines[1].newLine == 4)
        #expect(diff.lines[2].oldLine == 5)
        #expect(diff.lines[2].newLine == nil)
        #expect(diff.lines[3].oldLine == nil)
        #expect(diff.lines[3].newLine == 5)
        #expect(diff.lines[4].newLine == 6)
    }
}

@Suite("Git process client", .serialized)
struct GitProcessClientIntegrationTests {
    @Test("Stages, commits, branches, diffs, history, stashes, and publishes")
    func repositoryWorkflow() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerGitClient-\(UUID().uuidString)", isDirectory: true)
        let remote = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlunnerGitRemote-\(UUID().uuidString).git", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: remote)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try runGit(["init", "--bare", remote.path], at: FileManager.default.temporaryDirectory)
        try runGit(["init", "--initial-branch=main"], at: root)
        try runGit(["config", "user.name", "Flunner Tests"], at: root)
        try runGit(["config", "user.email", "tests@flugger.local"], at: root)
        try runGit(["remote", "add", "origin", remote.path], at: root)

        let client = GitProcessClient()
        let fileURL = root.appendingPathComponent("Example.swift")
        try "let value = 1\n".write(to: fileURL, atomically: true, encoding: .utf8)

        var snapshot = try await client.snapshot(at: root)
        #expect(snapshot.files.first?.isUntracked == true)

        try await client.stageAll(at: root)
        try await client.unstage(paths: ["Example.swift"], at: root)
        snapshot = try await client.snapshot(at: root)
        #expect(snapshot.files.first?.isUntracked == true)

        try await client.stageAll(at: root)
        try await client.commit(message: "Initial commit", at: root)
        try await client.publish(branch: "main", remote: "origin", at: root)

        try "let value = 2\n".write(to: fileURL, atomically: true, encoding: .utf8)
        snapshot = try await client.snapshot(at: root)
        let changed = try #require(snapshot.files.first { $0.path == "Example.swift" })
        let diff = try await client.diff(
            at: root,
            selection: GitFileSelection(file: changed, comparison: .workingTree)
        )
        #expect(diff.lines.contains { $0.kind == .removed && $0.text.contains("value = 1") })
        #expect(diff.lines.contains { $0.kind == .added && $0.text.contains("value = 2") })

        try await client.createStash(message: "Work in progress", includeUntracked: false, at: root)
        let stashes = try await client.stashes(at: root)
        #expect(stashes.count == 1)
        try await client.popStash(stashes[0].reference, at: root)

        try await client.stageAll(at: root)
        try await client.commit(message: "Update value", at: root)
        try await client.createBranch("feature/test", startPoint: nil, at: root)

        let branches = try await client.branches(at: root)
        #expect(branches.contains { $0.name == "feature/test" && $0.isCurrent })
        let history = try await client.history(at: root, offset: 0, limit: 100)
        #expect(history.map(\.subject).prefix(2) == ["Update value", "Initial commit"])
    }

    private func runGit(_ arguments: [String], at directory: URL) throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path] + arguments
        process.standardOutput = output
        process.standardError = output
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["LC_ALL"] = "C"
        process.environment = environment
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw GitClientError(command: "prepare test repository", message: text, exitCode: process.terminationStatus)
        }
    }
}

@MainActor
@Suite("Source control view model")
struct SourceControlViewModelTests {
    @Test("Loads a repository and keeps commit drafts per root")
    func repositoryLoadingAndDraftIsolation() async throws {
        let first = URL(fileURLWithPath: "/tmp/First")
        let second = URL(fileURLWithPath: "/tmp/Second")
        let client = MockGitClient(roots: [first.path: first, second.path: second])
        let viewModel = SourceControlViewModel(client: client)

        viewModel.setProjectPath(first.path)
        try await waitUntil { viewModel.snapshot?.rootURL == first }
        viewModel.commitMessage = "First draft"

        viewModel.setProjectPath(second.path)
        try await waitUntil { viewModel.snapshot?.rootURL == second }
        viewModel.commitMessage = "Second draft"

        viewModel.setProjectPath(first.path)
        try await waitUntil { viewModel.snapshot?.rootURL == first }
        #expect(viewModel.commitMessage == "First draft")
    }

    @Test("Reports a project without a repository")
    func missingRepository() async throws {
        let client = MockGitClient(roots: [:])
        let viewModel = SourceControlViewModel(client: client)
        viewModel.setProjectPath("/tmp/NoRepository")
        try await waitUntil { viewModel.isRepositoryMissing }
        #expect(viewModel.snapshot == nil)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now >= deadline {
                Issue.record("Timed out waiting for source control state.")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

private actor MockGitClient: GitClientProtocol {
    let roots: [String: URL]

    init(roots: [String: URL]) {
        self.roots = roots
    }

    func repositoryRoot(from projectURL: URL) async throws -> URL? { roots[projectURL.path] }
    func initializeRepository(at projectURL: URL) async throws -> URL { projectURL }
    func snapshot(at repositoryURL: URL) async throws -> GitRepositorySnapshot {
        GitRepositorySnapshot(
            rootURL: repositoryURL,
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            isUnborn: false,
            operation: nil,
            files: [],
            remotes: []
        )
    }
    func diff(at repositoryURL: URL, selection: GitFileSelection) async throws -> GitDiff { .parse(title: selection.file.path, text: "") }
    func commitDiff(at repositoryURL: URL, commit: GitCommit) async throws -> GitDiff { .parse(title: commit.subject, text: "") }
    func branches(at repositoryURL: URL) async throws -> [GitBranch] { [] }
    func history(at repositoryURL: URL, offset: Int, limit: Int) async throws -> [GitCommit] { [] }
    func stashes(at repositoryURL: URL) async throws -> [GitStash] { [] }
    func stage(paths: [String], at repositoryURL: URL) async throws { }
    func stageAll(at repositoryURL: URL) async throws { }
    func unstage(paths: [String], at repositoryURL: URL) async throws { }
    func unstageAll(at repositoryURL: URL) async throws { }
    func discard(paths: [String], at repositoryURL: URL) async throws { }
    func commit(message: String, at repositoryURL: URL) async throws { }
    func amendCommit(message: String, at repositoryURL: URL) async throws { }
    func fetch(at repositoryURL: URL) async throws { }
    func pull(at repositoryURL: URL) async throws { }
    func push(at repositoryURL: URL) async throws { }
    func publish(branch: String, remote: String, at repositoryURL: URL) async throws { }
    func switchBranch(_ name: String, at repositoryURL: URL) async throws { }
    func createBranch(_ name: String, startPoint: String?, at repositoryURL: URL) async throws { }
    func renameCurrentBranch(to name: String, at repositoryURL: URL) async throws { }
    func deleteBranch(_ name: String, at repositoryURL: URL) async throws { }
    func mergeBranch(_ name: String, at repositoryURL: URL) async throws { }
    func rebase(onto name: String, at repositoryURL: URL) async throws { }
    func continueOperation(_ operation: GitRepositoryOperation, at repositoryURL: URL) async throws { }
    func abortOperation(_ operation: GitRepositoryOperation, at repositoryURL: URL) async throws { }
    func createStash(message: String?, includeUntracked: Bool, at repositoryURL: URL) async throws { }
    func applyStash(_ reference: String, at repositoryURL: URL) async throws { }
    func popStash(_ reference: String, at repositoryURL: URL) async throws { }
    func dropStash(_ reference: String, at repositoryURL: URL) async throws { }
    func revertCommit(_ sha: String, at repositoryURL: URL) async throws { }
}
