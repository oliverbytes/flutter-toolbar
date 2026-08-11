import Foundation

struct RecentProject: Codable, Hashable, Identifiable {
    var id: String { path }

    let path: String
    let displayName: String
    var lastOpenedAt: Date
    var lastDeviceId: String?
    var lastConfigurationName: String?
    var terminalWorkspace: TerminalWorkspaceSnapshot?

    init(
        path: String,
        displayName: String? = nil,
        lastOpenedAt: Date = .now,
        lastDeviceId: String? = nil,
        lastConfigurationName: String? = nil,
        terminalWorkspace: TerminalWorkspaceSnapshot? = nil
    ) {
        let canonicalPath = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        self.path = canonicalPath
        self.displayName = displayName ?? URL(fileURLWithPath: canonicalPath).lastPathComponent
        self.lastOpenedAt = lastOpenedAt
        self.lastDeviceId = lastDeviceId
        self.lastConfigurationName = lastConfigurationName
        self.terminalWorkspace = terminalWorkspace
    }
}

struct TerminalTabSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

struct TerminalWorkspaceSnapshot: Codable, Hashable {
    static let defaultPaneHeight = 260.0
    static let minimumPaneHeight = 160.0

    var isVisible: Bool
    var paneHeight: Double
    var tabs: [TerminalTabSnapshot]
    var selectedTabID: UUID?

    init(
        isVisible: Bool = false,
        paneHeight: Double = defaultPaneHeight,
        tabs: [TerminalTabSnapshot] = [],
        selectedTabID: UUID? = nil
    ) {
        self.isVisible = isVisible
        self.paneHeight = max(Self.minimumPaneHeight, paneHeight)
        self.tabs = tabs
        self.selectedTabID = tabs.contains(where: { $0.id == selectedTabID })
            ? selectedTabID
            : tabs.first?.id
    }
}

enum RunOutcome: String, Codable, CaseIterable, Hashable {
    case ended
    case stoppedByUser
    case failed
    case interrupted

    var label: String {
        switch self {
        case .ended: "Ended"
        case .stoppedByUser: "Stopped"
        case .failed: "Failed"
        case .interrupted: "Interrupted"
        }
    }

    var systemImage: String {
        switch self {
        case .ended: "checkmark.circle.fill"
        case .stoppedByUser: "stop.circle.fill"
        case .failed: "xmark.circle.fill"
        case .interrupted: "exclamationmark.circle.fill"
        }
    }
}

struct RunSession: Codable, Hashable, Identifiable {
    let id: UUID
    let projectPath: String
    let projectName: String
    let deviceId: String
    let deviceName: String
    let configurationName: String
    let startedAt: Date
    let endedAt: Date
    let outcome: RunOutcome

    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
}

enum WorkspaceSelection: Hashable {
    case console
    case project(String)
    case session(UUID)
}

enum WorkspaceValidationError: LocalizedError, Equatable {
    case missingDirectory
    case missingPubspec
    case notFlutterProject
    case unreadableProject

    var errorDescription: String? {
        switch self {
        case .missingDirectory: "The project folder no longer exists."
        case .missingPubspec: "This folder does not contain pubspec.yaml."
        case .notFlutterProject: "The selected folder is not a Flutter project."
        case .unreadableProject: "Flugger could not read this project."
        }
    }
}
