import XCTest
@testable import Flugger

final class LaunchConfigEditorTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FluggerLaunchConfigTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testAsDictionaryProducesValidJSONStructure() {
        let config = LaunchConfig(
            name: "My Debug",
            flutterMode: nil,
            program: "lib/main.dart",
            args: ["--verbose"],
            toolArgs: ["--web-port=8080"],
            deviceId: nil,
            env: nil
        )
        let dict = config.asDictionary()

        XCTAssertEqual(dict["type"] as? String, "dart")
        XCTAssertEqual(dict["request"] as? String, "launch")
        XCTAssertEqual(dict["name"] as? String, "My Debug")
        XCTAssertEqual(dict["program"] as? String, "lib/main.dart")
        XCTAssertEqual(dict["args"] as? [String], ["--verbose"])
        XCTAssertEqual(dict["toolArgs"] as? [String], ["--web-port=8080"])
        XCTAssertNil(dict["flutterMode"])
        XCTAssertNil(dict["deviceId"])
    }

    func testAsDictionaryOmitsEmptyValues() {
        let config = LaunchConfig(
            name: "Release",
            flutterMode: "release",
            program: nil,
            args: [],
            toolArgs: [],
            deviceId: nil,
            env: nil
        )
        let dict = config.asDictionary()

        XCTAssertEqual(dict["type"] as? String, "dart")
        XCTAssertEqual(dict["name"] as? String, "Release")
        XCTAssertEqual(dict["flutterMode"] as? String, "release")
        XCTAssertNil(dict["program"])
        XCTAssertNil(dict["args"])
        XCTAssertNil(dict["toolArgs"])
    }

    func testRoundTripParseSaveParse() throws {
        let configs = [
            LaunchConfig(
                name: "Debug",
                flutterMode: nil,
                program: "lib/main.dart",
                args: [],
                toolArgs: [],
                deviceId: nil,
                env: nil
            ),
            LaunchConfig(
                name: "Release",
                flutterMode: "release",
                program: nil,
                args: ["--verbose", "--no-sound-null-safety"],
                toolArgs: [],
                deviceId: "ios",
                env: nil
            ),
        ]

        try LaunchConfig.saveConfigs(dartConfigs: configs, to: temporaryDirectory.path)
        let parsed = LaunchConfig.parse(from: temporaryDirectory.path)

        XCTAssertEqual(parsed.count, 2)
        let sorted = parsed.sorted { $0.name < $1.name }
        XCTAssertEqual(sorted[0].name, "Debug")
        XCTAssertNil(sorted[0].flutterMode)
        XCTAssertEqual(sorted[0].program, "lib/main.dart")

        XCTAssertEqual(sorted[1].name, "Release")
        XCTAssertEqual(sorted[1].flutterMode, "release")
        XCTAssertEqual(sorted[1].args, ["--verbose", "--no-sound-null-safety"])
        XCTAssertEqual(sorted[1].deviceId, "ios")
    }

    func testSavingPreservesNonDartConfigs() throws {
        let vscodePath = temporaryDirectory.appendingPathComponent(".vscode")
        try FileManager.default.createDirectory(at: vscodePath, withIntermediateDirectories: true)
        let launchURL = vscodePath.appendingPathComponent("launch.json")

        let existing: [String: Any] = [
            "version": "0.2.0",
            "configurations": [
                ["type": "node", "request": "launch", "name": "Node App"] as [String: Any],
                ["type": "dart", "request": "launch", "name": "Old Debug", "program": "lib/main.dart"] as [String: Any],
            ],
        ]
        let existingData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try existingData.write(to: launchURL)

        let newConfigs = [
            LaunchConfig(name: "New Debug", flutterMode: nil, program: "lib/main_alt.dart", args: [], toolArgs: [], deviceId: nil, env: nil),
        ]
        try LaunchConfig.saveConfigs(dartConfigs: newConfigs, to: temporaryDirectory.path)

        let afterSaveData = try Data(contentsOf: launchURL)
        let afterJSON = try JSONSerialization.jsonObject(with: afterSaveData) as? [String: Any] ?? [:]
        let afterConfigs = afterJSON["configurations"] as? [[String: Any]] ?? []
        let afterNames = afterConfigs.map { "\($0["name"] ?? "nil")(type:\($0["type"] ?? "nil"))" }
        XCTAssertEqual(afterConfigs.count, 2, "saveConfigs should write 2 configs. Got: \(afterNames)")

        let fullFile = LaunchConfig.readFullConfigFile(from: temporaryDirectory.path)
        XCTAssertEqual(fullFile?.nonDartConfigurations.count, 1)
    }

    func testSaveToNonexistentDirectoryCreatesVSCode() throws {
        let configs = [
            LaunchConfig(
                name: "Profile",
                flutterMode: "profile",
                program: nil,
                args: [],
                toolArgs: [],
                deviceId: nil,
                env: nil
            ),
        ]
        try LaunchConfig.saveConfigs(dartConfigs: configs, to: temporaryDirectory.path)

        let launchPath = temporaryDirectory
            .appendingPathComponent(".vscode/launch.json").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: launchPath))

        let parsed = LaunchConfig.parse(from: temporaryDirectory.path)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "Profile")
    }

    func testParseReturnsEmptyForNonexistentFile() {
        let configs = LaunchConfig.parse(from: temporaryDirectory.path)
        XCTAssertTrue(configs.isEmpty)
    }

    func testReadFullConfigFileReturnsNilForNonexistentFile() {
        let file = LaunchConfig.readFullConfigFile(from: temporaryDirectory.path)
        XCTAssertNil(file)
    }
}
