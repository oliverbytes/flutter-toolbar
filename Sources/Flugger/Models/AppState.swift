import Foundation

enum AppState: Equatable {
    case idle
    case starting
    case running
    case stopping
    case error
    
    var isRunning: Bool {
        self == .running || self == .starting || self == .stopping
    }
    
    var canControl: Bool {
        self == .running
    }
}