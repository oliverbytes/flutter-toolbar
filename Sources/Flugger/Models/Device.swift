import Foundation

struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let platform: String
    let platformType: String?
    let category: String?
    let emulator: Bool
    let emulatorId: String?
    let ephemeral: Bool?
    
    var displayName: String {
        let typeLabel = emulator ? " Simulator" : ""
        let platformLabel = platformType.map { " (\($0))" } ?? ""
        return "\(name)\(typeLabel)\(platformLabel)"
    }

    var systemImage: String {
        let normalized = platform.lowercased()
        if normalized.contains("ios") || normalized.contains("iphone") { return "iphone" }
        if normalized.contains("android") { return "smartphone" }
        if normalized.contains("macos") || normalized.contains("darwin") { return "laptopcomputer" }
        if normalized.contains("web") || normalized.contains("chrome") { return "globe" }
        return emulator ? "rectangle.dashed" : "display"
    }
}

extension Device {
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let platform = dict["platform"] as? String else {
            return nil
        }
        self.id = id
        self.name = name
        self.platform = platform
        self.platformType = dict["platformType"] as? String
        self.category = dict["category"] as? String
        self.emulator = dict["emulator"] as? Bool ?? false
        self.emulatorId = dict["emulatorId"] as? String
        self.ephemeral = dict["ephemeral"] as? Bool
    }
}
