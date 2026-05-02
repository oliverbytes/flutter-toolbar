import Foundation
import Combine
import AppKit

@MainActor
class ToolbarViewModel: ObservableObject {
    @Published var projectPath: String?
    @Published var projectName: String = "Select Project"
    @Published var selectedDeviceId: String?
    @Published var devices: [Device] = []
    @Published var launchConfigs: [LaunchConfig] = []
    @Published var selectedLaunchConfigName: String?
    @Published var appState: AppState = .idle
    @Published var status: String = "Ready"
    @Published var logLines: [LogEntry] = []
    
    private let daemon = FlutterDaemon()
    private var runner: FlutterRunner?
    private var runnerCancellables = Set<AnyCancellable>()
    private var daemonCancellables = Set<AnyCancellable>()
    
    private func addLog(_ message: String, type: LogEntryType = .info) {
        let entry = LogEntry(text: message, type: type)
        logLines.append(entry)
        if logLines.count > 50 {
            logLines.removeFirst(logLines.count - 50)
        }
    }
    
    var isAppRunning: Bool {
        appState.isRunning
    }
    
    var hasValidSetup: Bool {
        projectPath != nil && selectedDeviceId != nil
    }

    var canRun: Bool {
        hasValidSetup && !isAppRunning
    }
    
    var canControl: Bool {
        appState.canControl
    }

    var selectedLaunchConfig: LaunchConfig? {
        launchConfigs.first { $0.name == selectedLaunchConfigName }
    }

    init() {
        daemon.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
                if let selectedId = self?.selectedDeviceId,
                   !devices.contains(where: { $0.id == selectedId }) {
                    self?.selectedDeviceId = nil
                }
            }
            .store(in: &daemonCancellables)
        
        daemon.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                if running {
                    self?.status = "Daemon ready"
                    self?.addLog("Daemon ready", type: .info)
                }
            }
            .store(in: &daemonCancellables)
        
        daemon.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if !(self?.isAppRunning ?? false) {
                    self?.status = status
                }
            }
            .store(in: &daemonCancellables)
        
        daemon.onLogOutput = { [weak self] message, type in
            self?.addLog(message, type: type)
        }
        daemon.start()
        
        if let savedPath = UserDefaultsStore.shared.lastProjectPath {
            let pubspecPath = (savedPath as NSString).appendingPathComponent("pubspec.yaml")
            if FileManager.default.fileExists(atPath: pubspecPath) {
                projectPath = savedPath
                projectName = URL(fileURLWithPath: savedPath).lastPathComponent
                let parsed = LaunchConfig.parse(from: savedPath)
                launchConfigs = parsed.isEmpty ? LaunchConfig.defaultConfigs() : parsed
                selectedLaunchConfigName = launchConfigs.first?.name
            }
        }
        
        selectedDeviceId = UserDefaultsStore.shared.lastDeviceId
    }
    
    func selectProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a Flutter project folder"
        
        panel.begin { [weak self] result in
            guard let self = self else { return }
            if result == .OK, let url = panel.url {
                let pubspecPath = url.appendingPathComponent("pubspec.yaml").path
                guard FileManager.default.fileExists(atPath: pubspecPath) else {
                    self.status = "Invalid project: no pubspec.yaml found"
                    self.addLog("Invalid project: no pubspec.yaml found", type: .error)
                    return
                }
                
                do {
                    let content = try String(contentsOfFile: pubspecPath, encoding: .utf8)
                    guard content.contains("flutter:") else {
                        self.status = "Invalid project: not a Flutter project"
                        self.addLog("Invalid project: not a Flutter project", type: .error)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.projectPath = url.path
                        self.projectName = url.lastPathComponent
                        UserDefaultsStore.shared.lastProjectPath = url.path
                        self.status = "Project selected: \(url.lastPathComponent)"
                        self.addLog("Project: \(url.lastPathComponent)", type: .command)

                        let parsed = LaunchConfig.parse(from: url.path)
                        self.launchConfigs = parsed.isEmpty ? LaunchConfig.defaultConfigs() : parsed
                        self.selectedLaunchConfigName = self.launchConfigs.first?.name
                    }
                } catch {
                    self.status = "Error reading pubspec.yaml"
                    self.addLog("Error: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    func runApp() {
        guard let projectPath = projectPath, let deviceId = selectedDeviceId else { return }
        
        runnerCancellables.removeAll()
        
        let newRunner = FlutterRunner(projectPath: projectPath, deviceId: deviceId)
        newRunner.onLogOutput = { [weak self] message, type in
            self?.addLog(message, type: type)
        }
        newRunner.$appState
            .sink { [weak self] state in
                self?.appState = state
                if case .idle = state {
                    self?.runner = nil
                    self?.runnerCancellables.removeAll()
                }
            }
            .store(in: &runnerCancellables)

        newRunner.$status
            .sink { [weak self] status in
                self?.status = status
            }
            .store(in: &runnerCancellables)
        
        self.runner = newRunner
        newRunner.start(with: selectedLaunchConfig)
    }
    
    func hotReload() {
        runner?.hotReload()
    }
    
    func hotRestart() {
        runner?.hotRestart()
    }
    
    func stopApp() {
        runner?.stop()
    }

    func clearLogs() {
        logLines.removeAll()
    }
}