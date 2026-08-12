import Foundation

protocol GitClientProtocol: Sendable {
    func repositoryRoot(from projectURL: URL) async throws -> URL?
    func initializeRepository(at projectURL: URL) async throws -> URL
    func snapshot(at repositoryURL: URL) async throws -> GitRepositorySnapshot
    func diff(at repositoryURL: URL, selection: GitFileSelection) async throws -> GitDiff
    func commitDiff(at repositoryURL: URL, commit: GitCommit) async throws -> GitDiff
    func branches(at repositoryURL: URL) async throws -> [GitBranch]
    func history(at repositoryURL: URL, offset: Int, limit: Int) async throws -> [GitCommit]
    func stashes(at repositoryURL: URL) async throws -> [GitStash]

    func stage(paths: [String], at repositoryURL: URL) async throws
    func stageAll(at repositoryURL: URL) async throws
    func unstage(paths: [String], at repositoryURL: URL) async throws
    func unstageAll(at repositoryURL: URL) async throws
    func discard(paths: [String], at repositoryURL: URL) async throws
    func commit(message: String, at repositoryURL: URL) async throws
    func amendCommit(message: String, at repositoryURL: URL) async throws
    func fetch(at repositoryURL: URL) async throws
    func pull(at repositoryURL: URL) async throws
    func push(at repositoryURL: URL) async throws
    func publish(branch: String, remote: String, at repositoryURL: URL) async throws

    func switchBranch(_ name: String, at repositoryURL: URL) async throws
    func createBranch(_ name: String, startPoint: String?, at repositoryURL: URL) async throws
    func renameCurrentBranch(to name: String, at repositoryURL: URL) async throws
    func deleteBranch(_ name: String, at repositoryURL: URL) async throws
    func mergeBranch(_ name: String, at repositoryURL: URL) async throws
    func rebase(onto name: String, at repositoryURL: URL) async throws
    func continueOperation(_ operation: GitRepositoryOperation, at repositoryURL: URL) async throws
    func abortOperation(_ operation: GitRepositoryOperation, at repositoryURL: URL) async throws

    func createStash(message: String?, includeUntracked: Bool, at repositoryURL: URL) async throws
    func applyStash(_ reference: String, at repositoryURL: URL) async throws
    func popStash(_ reference: String, at repositoryURL: URL) async throws
    func dropStash(_ reference: String, at repositoryURL: URL) async throws
    func revertCommit(_ sha: String, at repositoryURL: URL) async throws
}

struct GitProcessClient: GitClientProtocol {
    func repositoryRoot(from projectURL: URL) async throws -> URL? {
        let result = try await execute(
            ["-C", projectURL.path, "rev-parse", "--show-toplevel"],
            label: "find the repository",
            acceptedExitCodes: [0, 128]
        )
        guard result.exitCode == 0 else { return nil }
        let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path).standardizedFileURL
    }

    func initializeRepository(at projectURL: URL) async throws -> URL {
        _ = try await execute(["-C", projectURL.path, "init"], label: "initialize the repository")
        return try await repositoryRoot(from: projectURL) ?? projectURL.standardizedFileURL
    }

    func snapshot(at repositoryURL: URL) async throws -> GitRepositorySnapshot {
        let statusResult = try await execute(
            ["-C", repositoryURL.path, "status", "--porcelain=v2", "-z", "--branch"],
            label: "read repository status"
        )
        let parsed = GitStatusParser.parse(statusResult.standardOutputData)
        let remotes = try await loadRemotes(at: repositoryURL)
        let operation = await repositoryOperation(at: repositoryURL)

        return GitRepositorySnapshot(
            rootURL: repositoryURL,
            branch: parsed.branch,
            upstream: parsed.upstream,
            ahead: parsed.ahead,
            behind: parsed.behind,
            isUnborn: parsed.isUnborn,
            operation: operation,
            files: parsed.files,
            remotes: remotes
        )
    }

    func diff(at repositoryURL: URL, selection: GitFileSelection) async throws -> GitDiff {
        if selection.file.isUntracked {
            return try await untrackedDiff(at: repositoryURL, file: selection.file)
        }

        var arguments = ["-C", repositoryURL.path, "diff", "--no-ext-diff", "--no-color", "--unified=3"]
        if selection.comparison == .staged { arguments.append("--cached") }
        arguments.append(contentsOf: ["--", selection.file.path])
        let result = try await execute(arguments, label: "load the diff")
        return limitedDiff(title: selection.file.path, data: result.standardOutputData)
    }

    func commitDiff(at repositoryURL: URL, commit: GitCommit) async throws -> GitDiff {
        let result = try await execute(
            [
                "-C", repositoryURL.path, "show", "--no-ext-diff", "--no-color", "--format=fuller",
                "--stat", "--patch", commit.sha,
            ],
            label: "load commit details"
        )
        return limitedDiff(title: "\(commit.shortSHA) · \(commit.subject)", data: result.standardOutputData)
    }

    func branches(at repositoryURL: URL) async throws -> [GitBranch] {
        let format = "%(refname)%09%(refname:short)%09%(HEAD)%09%(upstream:short)%09%(objectname:short)"
        let result = try await execute(
            ["-C", repositoryURL.path, "for-each-ref", "--sort=refname", "--format=\(format)", "refs/heads", "refs/remotes"],
            label: "load branches"
        )

        return result.standardOutput.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 5 else { return nil }
            let fullName = fields[0]
            let isRemote = fullName.hasPrefix("refs/remotes/")
            guard !fields[1].hasSuffix("/HEAD") else { return nil }
            return GitBranch(
                fullName: fullName,
                name: fields[1],
                isCurrent: fields[2] == "*",
                isRemote: isRemote,
                upstream: fields[3].isEmpty ? nil : fields[3],
                shortSHA: fields[4]
            )
        }
    }

    func history(at repositoryURL: URL, offset: Int, limit: Int) async throws -> [GitCommit] {
        let format = "%H%x00%h%x00%an%x00%aI%x00%s%x00%D%x1e"
        let result = try await execute(
            [
                "-C", repositoryURL.path, "log", "--branches", "--remotes", "--date=iso-strict", "--format=\(format)",
                "--skip=\(max(0, offset))", "--max-count=\(max(1, limit))",
            ],
            label: "load commit history",
            acceptedExitCodes: [0, 128]
        )
        guard result.exitCode == 0 else { return [] }

        return result.standardOutput.split(separator: "\u{1e}").compactMap { record in
            let fields = record.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\0", omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count >= 6 else { return nil }
            return GitCommit(
                sha: fields[0],
                shortSHA: fields[1],
                author: fields[2],
                date: Self.parseDate(fields[3]),
                subject: fields[4],
                decorations: fields[5]
            )
        }
    }

    func stashes(at repositoryURL: URL) async throws -> [GitStash] {
        let format = "%gd%x00%H%x00%aI%x00%s%x1e"
        let result = try await execute(
            ["-C", repositoryURL.path, "stash", "list", "--date=iso-strict", "--format=\(format)"],
            label: "load stashes"
        )
        return result.standardOutput.split(separator: "\u{1e}").compactMap { record in
            let fields = record.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\0", omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count >= 4 else { return nil }
            return GitStash(reference: fields[0], sha: fields[1], date: Self.parseDate(fields[2]), subject: fields[3])
        }
    }

    func stage(paths: [String], at repositoryURL: URL) async throws {
        guard !paths.isEmpty else { return }
        _ = try await execute(["-C", repositoryURL.path, "add", "--"] + paths, label: "stage files")
    }

    func stageAll(at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "add", "--all"], label: "stage all changes")
    }

    func unstage(paths: [String], at repositoryURL: URL) async throws {
        guard !paths.isEmpty else { return }
        let result = try await execute(
            ["-C", repositoryURL.path, "restore", "--staged", "--"] + paths,
            label: "unstage files",
            acceptedExitCodes: [0, 128]
        )
        if result.exitCode != 0 {
            _ = try await execute(
                ["-C", repositoryURL.path, "rm", "--cached", "--ignore-unmatch", "--"] + paths,
                label: "unstage files in a new repository"
            )
        }
    }

    func unstageAll(at repositoryURL: URL) async throws {
        let result = try await execute(
            ["-C", repositoryURL.path, "restore", "--staged", ":/"],
            label: "unstage all changes",
            acceptedExitCodes: [0, 128]
        )
        if result.exitCode != 0 {
            _ = try await execute(
                ["-C", repositoryURL.path, "rm", "--cached", "--recursive", "--ignore-unmatch", "--", "."],
                label: "unstage all changes in a new repository"
            )
        }
    }

    func discard(paths: [String], at repositoryURL: URL) async throws {
        guard !paths.isEmpty else { return }
        _ = try await execute(["-C", repositoryURL.path, "restore", "--worktree", "--"] + paths, label: "discard changes")
    }

    func commit(message: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "commit", "-m", message], label: "create the commit")
    }

    func amendCommit(message: String, at repositoryURL: URL) async throws {
        _ = try await execute(
            ["-C", repositoryURL.path, "commit", "--amend", "-m", message],
            label: "amend the latest commit"
        )
    }

    func fetch(at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "fetch", "--prune"], label: "fetch from remotes")
    }

    func pull(at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "pull", "--ff-only"], label: "pull changes")
    }

    func push(at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "push"], label: "push changes")
    }

    func publish(branch: String, remote: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "push", "--set-upstream", remote, branch], label: "publish the branch")
    }

    func switchBranch(_ name: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "switch", name], label: "switch branches")
    }

    func createBranch(_ name: String, startPoint: String?, at repositoryURL: URL) async throws {
        var arguments = ["-C", repositoryURL.path, "switch", "-c", name]
        if let startPoint, !startPoint.isEmpty { arguments.append(startPoint) }
        _ = try await execute(arguments, label: "create the branch")
    }

    func renameCurrentBranch(to name: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "branch", "--move", name], label: "rename the branch")
    }

    func deleteBranch(_ name: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "branch", "--delete", name], label: "delete the branch")
    }

    func mergeBranch(_ name: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "merge", "--no-edit", name], label: "merge the branch")
    }

    func rebase(onto name: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "rebase", name], label: "rebase the branch")
    }

    func continueOperation(_ operation: GitRepositoryOperation, at repositoryURL: URL) async throws {
        let command = operation == .merge ? "merge" : operation.rawValue.replacingOccurrences(of: "cherryPick", with: "cherry-pick")
        _ = try await execute(["-C", repositoryURL.path, command, "--continue"], label: "continue the \(operation.rawValue)")
    }

    func abortOperation(_ operation: GitRepositoryOperation, at repositoryURL: URL) async throws {
        let command = operation == .merge ? "merge" : operation.rawValue.replacingOccurrences(of: "cherryPick", with: "cherry-pick")
        _ = try await execute(["-C", repositoryURL.path, command, "--abort"], label: "abort the \(operation.rawValue)")
    }

    func createStash(message: String?, includeUntracked: Bool, at repositoryURL: URL) async throws {
        var arguments = ["-C", repositoryURL.path, "stash", "push"]
        if includeUntracked { arguments.append("--include-untracked") }
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--message", message])
        }
        _ = try await execute(arguments, label: "stash changes")
    }

    func applyStash(_ reference: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "stash", "apply", reference], label: "apply the stash")
    }

    func popStash(_ reference: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "stash", "pop", reference], label: "pop the stash")
    }

    func dropStash(_ reference: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "stash", "drop", reference], label: "delete the stash")
    }

    func revertCommit(_ sha: String, at repositoryURL: URL) async throws {
        _ = try await execute(["-C", repositoryURL.path, "revert", "--no-edit", sha], label: "revert the commit")
    }

    private func loadRemotes(at repositoryURL: URL) async throws -> [GitRemote] {
        let namesResult = try await execute(["-C", repositoryURL.path, "remote"], label: "load remotes")
        var remotes: [GitRemote] = []
        for name in namesResult.standardOutput.split(separator: "\n").map(String.init) where !name.isEmpty {
            let fetch = try await execute(
                ["-C", repositoryURL.path, "remote", "get-url", name],
                label: "load remote",
                acceptedExitCodes: [0, 2]
            )
            let push = try await execute(
                ["-C", repositoryURL.path, "remote", "get-url", "--push", name],
                label: "load remote",
                acceptedExitCodes: [0, 2]
            )
            remotes.append(
                GitRemote(
                    name: name,
                    fetchURL: fetch.exitCode == 0 ? fetch.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    pushURL: push.exitCode == 0 ? push.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                )
            )
        }
        return remotes
    }

    private func repositoryOperation(at repositoryURL: URL) async -> GitRepositoryOperation? {
        let probes: [(String, GitRepositoryOperation)] = [
            ("rebase-merge", .rebase),
            ("rebase-apply", .rebase),
            ("MERGE_HEAD", .merge),
            ("CHERRY_PICK_HEAD", .cherryPick),
            ("REVERT_HEAD", .revert),
        ]

        for (path, operation) in probes {
            guard let result = try? await execute(
                ["-C", repositoryURL.path, "rev-parse", "--path-format=absolute", "--git-path", path],
                label: "read repository operation"
            ) else { continue }
            let resolved = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.fileExists(atPath: resolved) { return operation }
        }
        return nil
    }

    private func untrackedDiff(at repositoryURL: URL, file: GitFileStatus) async throws -> GitDiff {
        try await Task.detached(priority: .userInitiated) {
            let fileURL = repositoryURL.appendingPathComponent(file.path)
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: GitDiff.maximumBytes + 1) ?? Data()
            let truncated = data.count > GitDiff.maximumBytes
            let limited = data.prefix(GitDiff.maximumBytes)
            let isBinary = limited.contains(0)
            guard !isBinary, let contents = String(data: limited, encoding: .utf8) else {
                return GitDiff(title: file.path, lines: [], isBinary: true, isTruncated: truncated)
            }
            let text = "--- /dev/null\n+++ b/\(file.path)\n" + contents
                .split(separator: "\n", omittingEmptySubsequences: false)
                .prefix(GitDiff.maximumLines - 2)
                .map { "+" + $0 }
                .joined(separator: "\n")
            let lineTruncated = contents.split(separator: "\n", omittingEmptySubsequences: false).count > GitDiff.maximumLines - 2
            return GitDiff.parse(title: file.path, text: text, isTruncated: truncated || lineTruncated)
        }.value
    }

    private func limitedDiff(title: String, data: Data) -> GitDiff {
        let limitedData = data.prefix(GitDiff.maximumBytes)
        let byteTruncated = data.count > GitDiff.maximumBytes
        let isBinary = limitedData.contains(0)
        guard !isBinary, let value = String(data: limitedData, encoding: .utf8) else {
            return GitDiff(title: title, lines: [], isBinary: true, isTruncated: byteTruncated)
        }
        let lines = value.split(separator: "\n", omittingEmptySubsequences: false)
        let lineTruncated = lines.count > GitDiff.maximumLines
        let text = lines.prefix(GitDiff.maximumLines).joined(separator: "\n")
        let reportsBinary = text.contains("Binary files ") || text.contains("GIT binary patch")
        return GitDiff.parse(
            title: title,
            text: text,
            isBinary: reportsBinary,
            isTruncated: byteTruncated || lineTruncated
        )
    }

    private func execute(
        _ arguments: [String],
        label: String,
        acceptedExitCodes: Set<Int32> = [0]
    ) async throws -> GitCommandOutput {
        try await Task.detached(priority: .userInitiated) {
            try Self.executeSynchronously(arguments, label: label, acceptedExitCodes: acceptedExitCodes)
        }.value
    }

    private static func executeSynchronously(
        _ arguments: [String],
        label: String,
        acceptedExitCodes: Set<Int32>
    ) throws -> GitCommandOutput {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("FlunnerGit-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let outputURL = temporaryDirectory.appendingPathComponent("stdout")
        let errorURL = temporaryDirectory.appendingPathComponent("stderr")
        fileManager.createFile(atPath: outputURL.path, contents: nil)
        fileManager.createFile(atPath: errorURL.path, contents: nil)

        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_PAGER"] = "cat"
        environment["GIT_EDITOR"] = "true"
        environment["GIT_MERGE_AUTOEDIT"] = "no"
        process.environment = environment

        try process.run()
        process.waitUntilExit()
        try outputHandle.synchronize()
        try errorHandle.synchronize()

        let standardOutputData = try Data(contentsOf: outputURL)
        let standardErrorData = try Data(contentsOf: errorURL)
        let standardError = String(decoding: standardErrorData, as: UTF8.self)
        guard acceptedExitCodes.contains(process.terminationStatus) else {
            throw GitClientError(command: label, message: standardError, exitCode: process.terminationStatus)
        }
        return GitCommandOutput(
            standardOutputData: standardOutputData,
            standardError: standardError,
            exitCode: process.terminationStatus
        )
    }

    private static func parseDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) ?? .distantPast
    }
}

struct GitCommandOutput: Sendable {
    let standardOutputData: Data
    let standardError: String
    let exitCode: Int32

    var standardOutput: String { String(decoding: standardOutputData, as: UTF8.self) }
}

enum GitStatusParser {
    struct Result: Equatable, Sendable {
        var branch = "HEAD"
        var upstream: String?
        var ahead = 0
        var behind = 0
        var isUnborn = false
        var files: [GitFileStatus] = []
    }

    static func parse(_ data: Data) -> Result {
        let fields = data.split(separator: 0, omittingEmptySubsequences: true).map { String(decoding: $0, as: UTF8.self) }
        var result = Result()
        var index = 0

        while index < fields.count {
            let record = fields[index]
            if record.hasPrefix("# branch.head ") {
                result.branch = String(record.dropFirst("# branch.head ".count))
            } else if record.hasPrefix("# branch.upstream ") {
                result.upstream = String(record.dropFirst("# branch.upstream ".count))
            } else if record.hasPrefix("# branch.ab ") {
                let values = record.split(separator: " ")
                for value in values.dropFirst(2) {
                    if value.hasPrefix("+") { result.ahead = Int(value.dropFirst()) ?? 0 }
                    if value.hasPrefix("-") { result.behind = Int(value.dropFirst()) ?? 0 }
                }
            } else if record == "# branch.oid (initial)" {
                result.isUnborn = true
            } else if record.hasPrefix("1 ") {
                if let file = parseOrdinary(record) { result.files.append(file) }
            } else if record.hasPrefix("2 ") {
                let originalPath = index + 1 < fields.count ? fields[index + 1] : nil
                if let file = parseRename(record, originalPath: originalPath) { result.files.append(file) }
                index += 1
            } else if record.hasPrefix("u ") {
                if let file = parseUnmerged(record) { result.files.append(file) }
            } else if record.hasPrefix("? ") {
                let path = String(record.dropFirst(2))
                result.files.append(
                    GitFileStatus(path: path, originalPath: nil, indexStatus: "?", workTreeStatus: "?", kind: .untracked)
                )
            }
            index += 1
        }

        result.files.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return result
    }

    private static func parseOrdinary(_ record: String) -> GitFileStatus? {
        let fields = record.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
        guard fields.count == 9, fields[1].count == 2 else { return nil }
        let status = Array(fields[1])
        return GitFileStatus(
            path: String(fields[8]),
            originalPath: nil,
            indexStatus: status[0],
            workTreeStatus: status[1],
            kind: kind(index: status[0], workTree: status[1])
        )
    }

    private static func parseRename(_ record: String, originalPath: String?) -> GitFileStatus? {
        let fields = record.split(separator: " ", maxSplits: 9, omittingEmptySubsequences: false)
        guard fields.count == 10, fields[1].count == 2 else { return nil }
        let status = Array(fields[1])
        let score = fields[8].first
        return GitFileStatus(
            path: String(fields[9]),
            originalPath: originalPath,
            indexStatus: status[0],
            workTreeStatus: status[1],
            kind: score == "C" ? .copied : .renamed
        )
    }

    private static func parseUnmerged(_ record: String) -> GitFileStatus? {
        let fields = record.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
        guard fields.count == 11, fields[1].count == 2 else { return nil }
        let status = Array(fields[1])
        return GitFileStatus(
            path: String(fields[10]),
            originalPath: nil,
            indexStatus: status[0],
            workTreeStatus: status[1],
            kind: .conflicted
        )
    }

    private static func kind(index: Character, workTree: Character) -> GitFileKind {
        let value = workTree != "." ? workTree : index
        return switch value {
        case "M": .modified
        case "A": .added
        case "D": .deleted
        case "R": .renamed
        case "C": .copied
        case "T": .typeChanged
        case "U": .conflicted
        default: .unknown
        }
    }
}
