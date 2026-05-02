import Foundation

struct LaunchConfig: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let flutterMode: String?
    let program: String?
    let args: [String]
    let toolArgs: [String]
    let deviceId: String?
    let env: [String: String]?

    var displayName: String {
        if let mode = flutterMode, !mode.isEmpty, mode != "debug" {
            return "\(name) (\(mode))"
        }
        return name
    }

    /// Extra arguments to append after the base `flutter run` command.
    var extraArgs: String {
        var parts: [String] = []

        if let mode = flutterMode, !mode.isEmpty, mode != "debug" {
            parts.append("--\(mode)")
        }

        parts.append(contentsOf: toolArgs)

        if let program = program, !program.isEmpty {
            parts.append(program)
        }

        if !args.isEmpty {
            parts.append("--")
            parts.append(contentsOf: args)
        }

        return parts.joined(separator: " ")
    }

    static func parse(from projectPath: String) -> [LaunchConfig] {
        let launchJsonPath = (projectPath as NSString).appendingPathComponent(".vscode/launch.json")
        guard let data = FileManager.default.contents(atPath: launchJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let configurations = json["configurations"] as? [[String: Any]] else {
            return []
        }

        return configurations.compactMap { config in
            guard let type = config["type"] as? String, type == "dart",
                  let request = config["request"] as? String, request == "launch" else {
                return nil
            }

            return LaunchConfig(
                name: config["name"] as? String ?? "Unnamed",
                flutterMode: config["flutterMode"] as? String,
                program: config["program"] as? String,
                args: config["args"] as? [String] ?? [],
                toolArgs: config["toolArgs"] as? [String] ?? [],
                deviceId: config["deviceId"] as? String,
                env: config["env"] as? [String: String]
            )
        }
    }

    static func defaultConfigs() -> [LaunchConfig] {
        return [
            LaunchConfig(name: "Debug", flutterMode: nil, program: nil, args: [], toolArgs: [], deviceId: nil, env: nil),
            LaunchConfig(name: "Profile", flutterMode: "profile", program: nil, args: [], toolArgs: [], deviceId: nil, env: nil),
            LaunchConfig(name: "Release", flutterMode: "release", program: nil, args: [], toolArgs: [], deviceId: nil, env: nil),
        ]
    }
}
