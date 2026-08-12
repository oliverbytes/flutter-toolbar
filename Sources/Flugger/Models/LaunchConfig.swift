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

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": "dart",
            "request": "launch",
            "name": name,
        ]
        if let flutterMode, !flutterMode.isEmpty {
            dict["flutterMode"] = flutterMode
        }
        if let program, !program.isEmpty {
            dict["program"] = program
        }
        if !args.isEmpty {
            dict["args"] = args
        }
        if !toolArgs.isEmpty {
            dict["toolArgs"] = toolArgs
        }
        if let deviceId, !deviceId.isEmpty {
            dict["deviceId"] = deviceId
        }
        if let env, !env.isEmpty {
            dict["env"] = env
        }
        return dict
    }

    struct LaunchConfigFile {
        let version: String
        let nonDartConfigurations: [[String: Any]]
    }

    static func readFullConfigFile(from projectPath: String) -> LaunchConfigFile? {
        let launchJsonPath = (projectPath as NSString).appendingPathComponent(".vscode/launch.json")
        guard let fileData = FileManager.default.contents(atPath: launchJsonPath),
              let fileContents = String(data: fileData, encoding: .utf8),
              let data = normalizedJSONData(from: fileContents),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let version = json["version"] as? String ?? "0.2.0"
        let configurations = json["configurations"] as? [[String: Any]] ?? []
        let nonDart = configurations.filter { config in
            guard let type = config["type"] as? String, type == "dart",
                  let request = config["request"] as? String, request == "launch" else {
                return true
            }
            return false
        }
        return LaunchConfigFile(version: version, nonDartConfigurations: nonDart)
    }

    static func saveConfigs(
        dartConfigs: [LaunchConfig],
        to projectPath: String
    ) throws {
        let existingFile = readFullConfigFile(from: projectPath)
        let sortedConfigs = dartConfigs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let fullConfigs = (existingFile?.nonDartConfigurations ?? []) + sortedConfigs.map { $0.asDictionary() }

        let root: [String: Any] = [
            "version": existingFile?.version ?? "0.2.0",
            "configurations": fullConfigs,
        ]
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let vscodePath = (projectPath as NSString).appendingPathComponent(".vscode")
        let fileURL = URL(fileURLWithPath: vscodePath)
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true, attributes: nil)
        let launchURL = fileURL.appendingPathComponent("launch.json")
        try data.write(to: launchURL)
    }

    static func parse(from projectPath: String) -> [LaunchConfig] {
        let launchJsonPath = (projectPath as NSString).appendingPathComponent(".vscode/launch.json")
        guard let fileData = FileManager.default.contents(atPath: launchJsonPath),
              let fileContents = String(data: fileData, encoding: .utf8),
              let data = normalizedJSONData(from: fileContents),
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

    /// VS Code launch files are JSONC: comments and trailing commas are valid.
    /// `JSONSerialization` accepts only strict JSON, so normalize those features first.
    private static func normalizedJSONData(from contents: String) -> Data? {
        var uncommented = ""
        var index = contents.startIndex
        var isInString = false
        var isEscaped = false
        var isLineComment = false
        var isBlockComment = false

        while index < contents.endIndex {
            let character = contents[index]
            let nextIndex = contents.index(after: index)
            let nextCharacter = nextIndex < contents.endIndex ? contents[nextIndex] : nil

            if isLineComment {
                if character == "\n" {
                    isLineComment = false
                    uncommented.append(character)
                }
                index = nextIndex
                continue
            }

            if isBlockComment {
                if character == "*", nextCharacter == "/" {
                    isBlockComment = false
                    index = contents.index(after: nextIndex)
                } else {
                    if character == "\n" {
                        uncommented.append(character)
                    }
                    index = nextIndex
                }
                continue
            }

            if isInString {
                uncommented.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInString = false
                }
                index = nextIndex
                continue
            }

            if character == "\"" {
                isInString = true
                uncommented.append(character)
            } else if character == "/", nextCharacter == "/" {
                isLineComment = true
                index = contents.index(after: nextIndex)
                continue
            } else if character == "/", nextCharacter == "*" {
                isBlockComment = true
                index = contents.index(after: nextIndex)
                continue
            } else {
                uncommented.append(character)
            }

            index = nextIndex
        }

        var normalized = ""
        index = uncommented.startIndex
        isInString = false
        isEscaped = false

        while index < uncommented.endIndex {
            let character = uncommented[index]
            if isInString {
                normalized.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInString = false
                }
            } else if character == "\"" {
                isInString = true
                normalized.append(character)
            } else if character == "," {
                var lookAhead = uncommented.index(after: index)
                while lookAhead < uncommented.endIndex,
                      uncommented[lookAhead].isWhitespace {
                    lookAhead = uncommented.index(after: lookAhead)
                }
                if lookAhead < uncommented.endIndex,
                   uncommented[lookAhead] != "}",
                   uncommented[lookAhead] != "]" {
                    normalized.append(character)
                }
            } else {
                normalized.append(character)
            }
            index = uncommented.index(after: index)
        }

        return normalized.data(using: .utf8)
    }

    static func defaultConfigs() -> [LaunchConfig] {
        return [
            LaunchConfig(name: "Debug", flutterMode: nil, program: nil, args: [], toolArgs: [], deviceId: nil, env: nil),
            LaunchConfig(name: "Profile", flutterMode: "profile", program: nil, args: [], toolArgs: [], deviceId: nil, env: nil),
            LaunchConfig(name: "Release", flutterMode: "release", program: nil, args: [], toolArgs: [], deviceId: nil, env: nil),
        ]
    }
}
