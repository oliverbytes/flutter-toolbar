import Foundation

enum PreferenceKeys {
    static let themeMode = "themeMode"
    static let consoleFontSize = "fontSize"
    static let showTimestamps = "showTimestamps"
    static let followOutput = "followOutput"
}

@MainActor
class UserDefaultsStore {
    static let shared = UserDefaultsStore()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastProjectPath = "lastProjectPath"
        static let lastDeviceId = "lastDeviceId"
        static let lastLaunchConfigName = "lastLaunchConfigName"
        static let fontSize = "fontSize"
        static let themeMode = PreferenceKeys.themeMode
    }

    var themeMode: String {
        get { defaults.string(forKey: Keys.themeMode) ?? "system" }
        set { defaults.set(newValue, forKey: Keys.themeMode) }
    }

    var lastProjectPath: String? {
        get { defaults.string(forKey: Keys.lastProjectPath) }
        set { defaults.set(newValue, forKey: Keys.lastProjectPath) }
    }

    var lastDeviceId: String? {
        get { defaults.string(forKey: Keys.lastDeviceId) }
        set { defaults.set(newValue, forKey: Keys.lastDeviceId) }
    }

    var lastLaunchConfigName: String? {
        get { defaults.string(forKey: Keys.lastLaunchConfigName) }
        set { defaults.set(newValue, forKey: Keys.lastLaunchConfigName) }
    }

    var fontSize: CGFloat {
        get {
            let value = defaults.double(forKey: Keys.fontSize)
            return value > 0 ? value : 12
        }
        set { defaults.set(Double(newValue), forKey: Keys.fontSize) }
    }

    var showTimestamps: Bool {
        get { defaults.object(forKey: PreferenceKeys.showTimestamps) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PreferenceKeys.showTimestamps) }
    }

    var followOutput: Bool {
        get { defaults.object(forKey: PreferenceKeys.followOutput) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PreferenceKeys.followOutput) }
    }
}
