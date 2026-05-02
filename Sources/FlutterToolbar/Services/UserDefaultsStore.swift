import Foundation

@MainActor
class UserDefaultsStore {
    static let shared = UserDefaultsStore()
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let lastProjectPath = "lastProjectPath"
        static let lastDeviceId = "lastDeviceId"
    }
    
    var lastProjectPath: String? {
        get { defaults.string(forKey: Keys.lastProjectPath) }
        set { defaults.set(newValue, forKey: Keys.lastProjectPath) }
    }
    
    var lastDeviceId: String? {
        get { defaults.string(forKey: Keys.lastDeviceId) }
        set { defaults.set(newValue, forKey: Keys.lastDeviceId) }
    }
}