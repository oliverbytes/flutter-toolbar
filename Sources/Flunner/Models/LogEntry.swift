import Foundation

enum LogChannel: String, CaseIterable, Hashable, Identifiable {
    case console
    case output

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .console: "terminal"
        case .output: "text.alignleft"
        }
    }
}

enum LogEntryType: String, Codable, CaseIterable, Hashable {
    case info
    case error
    case command

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .info: "text.alignleft"
        case .error: "xmark.circle.fill"
        case .command: "chevron.right"
        }
    }
}

struct LogEntry: Identifiable, Hashable {
    let id: UUID
    let text: String
    let type: LogEntryType
    let timestamp: Date

    init(id: UUID = UUID(), text: String, type: LogEntryType, timestamp: Date = .now) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
    }
}

enum ConsoleLogTools {
    static func filter(
        _ entries: [LogEntry],
        query: String,
        enabledTypes: Set<LogEntryType>
    ) -> [LogEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty selection means "no type filter" — show every type.
        let typeFilterActive = !enabledTypes.isEmpty
        return entries.filter { entry in
            if typeFilterActive, !enabledTypes.contains(entry.type) { return false }
            return needle.isEmpty || entry.text.localizedCaseInsensitiveContains(needle)
        }
    }

    static func exportText(_ entries: [LogEntry]) -> String {
        entries.map { entry in
            "[\(entry.timestamp.formatted(.iso8601.time(includingFractionalSeconds: true)))] [\(entry.type.rawValue.uppercased())] \(entry.text)"
        }
        .joined(separator: "\n")
    }
}
