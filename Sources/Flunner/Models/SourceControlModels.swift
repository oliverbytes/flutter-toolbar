import Foundation

enum SourceControlSection: String, CaseIterable, Identifiable {
    case changes
    case history

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum GitFileKind: String, Sendable {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case untracked
    case conflicted
    case typeChanged
    case unknown

    var label: String {
        switch self {
        case .modified: "Modified"
        case .added: "Added"
        case .deleted: "Deleted"
        case .renamed: "Renamed"
        case .copied: "Copied"
        case .untracked: "Untracked"
        case .conflicted: "Conflict"
        case .typeChanged: "Type Changed"
        case .unknown: "Changed"
        }
    }

    var abbreviation: String {
        switch self {
        case .modified: "M"
        case .added: "A"
        case .deleted: "D"
        case .renamed: "R"
        case .copied: "C"
        case .untracked: "U"
        case .conflicted: "!"
        case .typeChanged: "T"
        case .unknown: "•"
        }
    }
}

struct GitFileStatus: Identifiable, Hashable, Sendable {
    let path: String
    let originalPath: String?
    let indexStatus: Character
    let workTreeStatus: Character
    let kind: GitFileKind

    var id: String { path }
    var displayName: String { URL(fileURLWithPath: path).lastPathComponent }

    var parentPath: String {
        let parent = (path as NSString).deletingLastPathComponent
        return parent == "." || parent.isEmpty ? "" : parent
    }

    var hasStagedChanges: Bool { indexStatus != "." && indexStatus != " " && indexStatus != "?" }
    var hasWorkingTreeChanges: Bool { workTreeStatus != "." && workTreeStatus != " " }
    var isUntracked: Bool { indexStatus == "?" || kind == .untracked }
    var isConflicted: Bool { kind == .conflicted }
}

enum GitComparison: String, Hashable, Sendable {
    case staged
    case workingTree
}

struct GitFileSelection: Identifiable, Hashable, Sendable {
    let file: GitFileStatus
    let comparison: GitComparison

    var id: String { "\(comparison.rawValue):\(file.path)" }
}

enum GitRepositoryOperation: String, Sendable {
    case merge
    case rebase
    case cherryPick
    case revert

    var label: String {
        switch self {
        case .merge: "Merge in progress"
        case .rebase: "Rebase in progress"
        case .cherryPick: "Cherry-pick in progress"
        case .revert: "Revert in progress"
        }
    }
}

struct GitRemote: Identifiable, Hashable, Sendable {
    let name: String
    let fetchURL: String?
    let pushURL: String?
    var id: String { name }
}

struct GitRepositorySnapshot: Hashable, Sendable {
    let rootURL: URL
    let branch: String
    let upstream: String?
    let ahead: Int
    let behind: Int
    let isUnborn: Bool
    let operation: GitRepositoryOperation?
    let files: [GitFileStatus]
    let remotes: [GitRemote]

    var changeCount: Int {
        files.reduce(into: 0) { count, file in
            if file.hasStagedChanges { count += 1 }
            if file.hasWorkingTreeChanges || file.isUntracked { count += 1 }
        }
    }

    var hasStagedChanges: Bool { files.contains(where: \.hasStagedChanges) }
    var hasWorkingTreeChanges: Bool {
        files.contains { $0.hasWorkingTreeChanges || $0.isUntracked }
    }
}

struct GitBranch: Identifiable, Hashable, Sendable {
    let fullName: String
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
    let upstream: String?
    let shortSHA: String

    var id: String { fullName }
}

struct GitCommit: Identifiable, Hashable, Sendable {
    let sha: String
    let shortSHA: String
    let author: String
    let date: Date
    let subject: String
    let decorations: String

    var id: String { sha }
}

struct GitStash: Identifiable, Hashable, Sendable {
    let reference: String
    let sha: String
    let date: Date
    let subject: String

    var id: String { reference }
}

enum GitDiffLineKind: Sendable {
    case context
    case added
    case removed
    case header
}

struct GitDiffLine: Identifiable, Hashable, Sendable {
    let id: Int
    let oldLine: Int?
    let newLine: Int?
    let text: String
    let kind: GitDiffLineKind
}

struct GitDiff: Hashable, Sendable {
    static let maximumBytes = 2_000_000
    static let maximumLines = 20_000

    let title: String
    let lines: [GitDiffLine]
    let isBinary: Bool
    let isTruncated: Bool

    static func parse(title: String, text: String, isBinary: Bool = false, isTruncated: Bool = false) -> GitDiff {
        var oldLine: Int?
        var newLine: Int?
        var parsed: [GitDiffLine] = []

        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let value = String(line)
            let kind: GitDiffLineKind
            var displayedOld: Int?
            var displayedNew: Int?

            if value.hasPrefix("@@") {
                kind = .header
                let ranges = value.split(separator: " ")
                if ranges.count >= 3 {
                    oldLine = Self.rangeStart(String(ranges[1]))
                    newLine = Self.rangeStart(String(ranges[2]))
                }
            } else if value.hasPrefix("+") && !value.hasPrefix("+++") {
                kind = .added
                displayedNew = newLine
                newLine = newLine.map { $0 + 1 }
            } else if value.hasPrefix("-") && !value.hasPrefix("---") {
                kind = .removed
                displayedOld = oldLine
                oldLine = oldLine.map { $0 + 1 }
            } else if value.hasPrefix("diff ") || value.hasPrefix("index ") || value.hasPrefix("---") || value.hasPrefix("+++") {
                kind = .header
            } else {
                kind = .context
                if oldLine != nil || newLine != nil {
                    displayedOld = oldLine
                    displayedNew = newLine
                    oldLine = oldLine.map { $0 + 1 }
                    newLine = newLine.map { $0 + 1 }
                }
            }

            parsed.append(
                GitDiffLine(
                    id: index,
                    oldLine: displayedOld,
                    newLine: displayedNew,
                    text: value,
                    kind: kind
                )
            )
        }

        return GitDiff(title: title, lines: parsed, isBinary: isBinary, isTruncated: isTruncated)
    }

    private static func rangeStart(_ range: String) -> Int? {
        let cleaned = range.dropFirst()
        return Int(cleaned.split(separator: ",").first ?? "")
    }
}

enum SourceControlActivity: Equatable, Sendable {
    case idle
    case refreshing
    case running(String)

    var label: String? {
        switch self {
        case .idle: nil
        case .refreshing: "Refreshing Source Control…"
        case let .running(label): label
        }
    }
}

struct GitClientError: LocalizedError, Equatable, Sendable {
    let command: String
    let message: String
    let exitCode: Int32

    var errorDescription: String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Git could not complete \(command)." : trimmed
    }
}
