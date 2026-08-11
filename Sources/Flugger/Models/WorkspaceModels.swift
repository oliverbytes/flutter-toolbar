import Foundation

struct RecentProject: Codable, Hashable, Identifiable {
    var id: String { path }

    let path: String
    let displayName: String
    var lastOpenedAt: Date
    var lastDeviceId: String?
    var lastConfigurationName: String?

    init(
        path: String,
        displayName: String? = nil,
        lastOpenedAt: Date = .now,
        lastDeviceId: String? = nil,
        lastConfigurationName: String? = nil
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
