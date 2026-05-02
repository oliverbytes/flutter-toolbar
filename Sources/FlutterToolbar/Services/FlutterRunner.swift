import Foundation
import Combine

@MainActor
class FlutterRunner: ObservableObject {
    @Published var appState: AppState = .idle
    @Published var appId: String?
    @Published var status: String = "Idle"
    var onLogOutput: ((String, LogEntryType) -> Void)?
    
    private var process: Process?
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private var requestId = 0
    private let projectPath: String
    private let deviceId: String
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    
    init(projectPath: String, deviceId: String) {
        self.projectPath = projectPath
        self.deviceId = deviceId
    }
    
    func start(with launchConfig: LaunchConfig? = nil) {
        var command = "flutter run --machine --suppress-analytics -d \(deviceId)"

        if let config = launchConfig {
            let extra = config.extraArgs
            if !extra.isEmpty {
                command += " \(extra)"
            }
        } else {
            command += " lib/main.dart"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", command]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        if let env = launchConfig?.env, !env.isEmpty {
            var mergedEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                mergedEnv[key] = value
            }
            process.environment = mergedEnv
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.appState != .idle && self.appState != .error {
                    self.appState = .idle
                    self.appId = nil
                    self.status = "App terminated"
                    self.onLogOutput?("App terminated", .info)
                }
                self.process = nil
            }
        }
        
        let stdoutHandle = stdoutPipe.fileHandleForReading
        stdoutHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.processBuffer(data: data, isStderr: false)
            }
        }
        
        let stderrHandle = stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.processBuffer(data: data, isStderr: true)
            }
        }
        
        do {
            onLogOutput?("flutter run -d \(deviceId)", .command)
            try process.run()
            self.process = process
            self.appState = .starting
            self.status = "Starting app..."
        } catch {
            self.appState = .error
            self.status = "Failed to start: \(error.localizedDescription)"
            onLogOutput?("Error: \(error.localizedDescription)", .error)
        }
    }
    
    func stop() {
        guard appState == .running || appState == .starting else { return }
        appState = .stopping
        status = "Stopping..."
        onLogOutput?("Stopping...", .info)

        if let appId = appId {
            sendRequest(method: "app.stop", params: ["appId": appId])
        } else {
            // No appId yet, just kill the process
            terminateProcess(force: false)
            return
        }

        // Give the flutter tool up to 8 seconds to gracefully stop the app.
        // It will send an app.stop event and then exit on its own.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self else { return }
            if self.process != nil {
                self.terminateProcess(force: true)
            }
        }
    }

    private func terminateProcess(force: Bool) {
        guard let process = process else {
            if appState == .stopping {
                appState = .idle
                appId = nil
                status = "Stopped"
            }
            return
        }

        if force {
            process.terminate()
            onLogOutput?("Force killed flutter process", .error)
        } else {
            process.interrupt()
            onLogOutput?("Interrupted flutter process", .info)
        }
    }
    
    func hotReload() {
        guard let appId = appId else { return }
        sendRequest(method: "app.restart", params: [
            "appId": appId,
            "fullRestart": false,
            "reason": "manual",
            "debounce": true
        ])
        status = "Hot reloading..."
        onLogOutput?("Hot reload", .command)
    }
    
    func hotRestart() {
        guard let appId = appId else { return }
        sendRequest(method: "app.restart", params: [
            "appId": appId,
            "fullRestart": true,
            "reason": "manual",
            "debounce": true
        ])
        status = "Hot restarting..."
        onLogOutput?("Hot restart", .command)
    }
    
    private func sendRequest(method: String, params: [String: Any]) {
        requestId += 1
        let request: [[String: Any]] = [[
            "id": requestId,
            "method": method,
            "params": params
        ]]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let string = String(data: data, encoding: .utf8) else { return }
        
        if let inputData = "\(string)\n".data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(inputData)
        }
    }
    
    private func processBuffer(data: Data, isStderr: Bool) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        
        if isStderr {
            stderrBuffer += normalized
        } else {
            stdoutBuffer += normalized
        }
        
        let buffer = isStderr ? stderrBuffer : stdoutBuffer
        
        if buffer.contains("\n") {
            let lines = buffer.components(separatedBy: "\n")
            let completeLines = lines.dropLast()
            let remaining = lines.last ?? ""
            
            if isStderr {
                stderrBuffer = remaining
            } else {
                stdoutBuffer = remaining
            }
            
            for line in completeLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                let isMachineMessage = trimmed.hasPrefix("[{") && trimmed.hasSuffix("}]")
                if isMachineMessage {
                    if let lineData = trimmed.data(using: .utf8) {
                        let messages = RunnerMessage.parse(data: lineData)
                        for message in messages {
                            handleMessage(message)
                        }
                    }
                } else {
                    let type: LogEntryType = isStderr ? .error : classifyOutput(trimmed)
                    onLogOutput?(trimmed, type)
                }
            }
        }
    }
    
    private func classifyOutput(_ text: String) -> LogEntryType {
        let lower = text.lowercased()
        if lower.hasPrefix("error") || lower.contains("error:") || lower.contains("exception") || lower.contains("failed") || lower.contains("failure") {
            return .error
        }
        if lower.hasPrefix("flutter") || lower.hasPrefix("building") || lower.hasPrefix("compiling") || lower.hasPrefix("running") {
            return .command
        }
        return .info
    }
    
    private func handleMessage(_ message: RunnerMessage) {
        if let error = message.error {
            appState = .error
            status = "Error: \(error)"
            onLogOutput?("Error: \(error)", .error)
            return
        }
        
        if let event = message.event {
            switch event {
            case "app.start":
                appId = message.appId
                appState = .starting
                status = "App starting..."
            case "app.started":
                appState = .running
                status = "App running"
                onLogOutput?("App running", .info)
            case "app.debugPort":
                status = "Debug connected"
                onLogOutput?("Debug connected", .info)
            case "app.progress":
                if let msg = message.progressMessage {
                    status = msg
                    onLogOutput?(msg, .info)
                }
                if message.progressFinished == true {
                    appState = .running
                    status = "App running"
                }
            case "app.stop":
                appState = .idle
                appId = nil
                status = "App stopped"
                onLogOutput?("App stopped", .info)
            default:
                break
            }
        }
    }
}