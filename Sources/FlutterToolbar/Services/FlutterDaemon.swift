import Foundation
import Combine

@MainActor
class FlutterDaemon: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isRunning = false
    @Published var status: String = "Starting daemon..."
    var onLogOutput: ((String, LogEntryType) -> Void)?
    
    private var process: Process?
    private let stdoutPipe = Pipe()
    private let stdinPipe = Pipe()
    private let stderrPipe = Pipe()
    private var requestId = 0
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    
    func start() {
        guard !isRunning else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", "flutter daemon"]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.status = "Daemon stopped"
                self?.devices.removeAll()
                self?.onLogOutput?("Daemon stopped", .error)
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
            onLogOutput?("flutter daemon", .command)
            try process.run()
            self.process = process
            self.isRunning = true
            self.status = "Daemon running"
            sendRequest(method: "device.enable", params: [:])
        } catch {
            self.status = "Failed to start daemon: \(error.localizedDescription)"
            onLogOutput?("Error: \(error.localizedDescription)", .error)
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        devices.removeAll()
    }
    
    func refreshDevices() {
        sendRequest(method: "device.getDevices", params: [:])
    }
    
    func launchEmulator(_ emulatorId: String) {
        sendRequest(method: "emulator.launch", params: ["emulatorId": emulatorId])
    }
    
    private func sendRequest(method: String, params: [String: Any]) {
        requestId += 1
        let id = requestId
        let request: [[String: Any]] = [[
            "id": id,
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
                
                if !isStderr && trimmed.hasPrefix("[{") && trimmed.hasSuffix("}]") {
                    if let lineData = trimmed.data(using: .utf8) {
                        let messages = DaemonMessage.parse(data: lineData)
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
        if lower.hasPrefix("flutter") || lower.hasPrefix("building") || lower.hasPrefix("downloading") || lower.hasPrefix("starting") {
            return .command
        }
        return .info
    }
    
    private func handleMessage(_ message: DaemonMessage) {
        if let error = message.error {
            status = "Daemon error: \(error)"
            onLogOutput?("Daemon error: \(error)", .error)
            return
        }
        
        if let event = message.event {
            switch event {
            case "device.added":
                if let device = message.device,
                   !devices.contains(where: { $0.id == device.id }) {
                    devices.append(device)
                    status = "Device added: \(device.name)"
                    onLogOutput?("Device: \(device.displayName)", .info)
                }
            case "device.removed":
                if let device = message.device {
                    devices.removeAll { $0.id == device.id }
                    status = "Device removed: \(device.name)"
                    onLogOutput?("Device removed: \(device.name)", .info)
                }
            case "daemon.connected":
                status = "Daemon connected"
                onLogOutput?("Daemon connected", .info)
            case "daemon.logMessage":
                break
            default:
                break
            }
        }
    }
}