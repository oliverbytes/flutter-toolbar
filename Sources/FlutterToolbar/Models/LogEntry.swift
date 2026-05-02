import Foundation

enum LogEntryType: Equatable {
    case info
    case error
    case command
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: LogEntryType
}