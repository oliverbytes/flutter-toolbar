import Foundation

struct WorkspaceSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var recentProjects: [RecentProject] = []
    var sessions: [RunSession] = []
}

final class WorkspaceStore {
    static let recentProjectLimit = 10
    static let sessionLimit = 30

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = directoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flugger", isDirectory: true)
        fileURL = directory.appendingPathComponent("workspace.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> WorkspaceSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else { return WorkspaceSnapshot() }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(WorkspaceSnapshot.self, from: data)
    }

    @discardableResult
    func upsert(_ project: RecentProject, in snapshot: inout WorkspaceSnapshot) throws -> RecentProject {
        var normalized = project
        normalized.lastOpenedAt = .now
        snapshot.recentProjects.removeAll { $0.path == normalized.path }
        snapshot.recentProjects.insert(normalized, at: 0)
        snapshot.recentProjects = Array(snapshot.recentProjects.prefix(Self.recentProjectLimit))
        try save(snapshot)
        return normalized
    }

    func removeProject(path: String, from snapshot: inout WorkspaceSnapshot) throws {
        snapshot.recentProjects.removeAll { $0.path == path }
        try save(snapshot)
    }

    func updateProject(_ project: RecentProject, in snapshot: inout WorkspaceSnapshot) throws {
        guard let index = snapshot.recentProjects.firstIndex(where: { $0.path == project.path }) else {
            _ = try upsert(project, in: &snapshot)
            return
        }
        snapshot.recentProjects[index] = project
        try save(snapshot)
    }

    func append(_ session: RunSession, to snapshot: inout WorkspaceSnapshot) throws {
        snapshot.sessions.removeAll { $0.id == session.id }
        snapshot.sessions.insert(session, at: 0)
        snapshot.sessions = Array(snapshot.sessions.prefix(Self.sessionLimit))
        try save(snapshot)
    }

    func removeSession(id: UUID, from snapshot: inout WorkspaceSnapshot) throws {
        snapshot.sessions.removeAll { $0.id == id }
        try save(snapshot)
    }

    func clearHistory(in snapshot: inout WorkspaceSnapshot) throws {
        snapshot.sessions.removeAll()
        try save(snapshot)
    }

    func save(_ snapshot: WorkspaceSnapshot) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}
