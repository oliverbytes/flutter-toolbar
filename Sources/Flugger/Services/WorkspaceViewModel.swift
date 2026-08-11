import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    static let maximumLogEntries = 10_000

    @Published private(set) var projectPath: String?
    @Published private(set) var projectName = "No Project"
    @Published private(set) var devices: [Device] = []
    @Published private(set) var launchConfigs: [LaunchConfig] = []
    @Published var selectedDeviceId: String?
    @Published var selectedLaunchConfigName: String?
    @Published private(set) var appState: AppState = .idle
    @Published private(set) var status = "Preparing Flutter tools…"
    @Published private(set) var logLines: [LogEntry] = []
    @Published private(set) var recentProjects: [RecentProject] = []
    @Published private(set) var sessions: [RunSession] = []
    @Published private(set) var projectRunStates: [String: AppState] = [:]
    @Published var selection: WorkspaceSelection = .console
    @Published private(set) var selectedLogChannel: LogChannel = .console
    @Published private var searchTextByChannel: [LogChannel: String] = [
        .console: "",
        .output: "",
    ]
    @Published private var enabledLogTypesByChannel: [LogChannel: Set<LogEntryType>] = [
        .console: Set(LogEntryType.allCases),
        .output: Set(LogEntryType.allCases),
    ]
    @Published var isCleanConfirmationPresented = false
    @Published private(set) var isProjectMaintenanceRunning = false
    @Published private(set) var activeMaintenanceProjectPath: String?

    private let daemon: FlutterDaemon
    private let store: WorkspaceStore
    private let projectMaintenance: FlutterProjectMaintaining
    private let runnerFactory: @MainActor (String, String) -> FlutterRunner
    private var snapshot: WorkspaceSnapshot
    private var runnersByProject: [String: FlutterRunner] = [:]
    private var runnerCancellablesByProject: [String: Set<AnyCancellable>] = [:]
    private var projectStatuses: [String: String] = [:]
    private var daemonCancellables = Set<AnyCancellable>()
    private var activeRunsByProject: [String: ActiveRun] = [:]
    private var logsByBuffer: [LogBufferKey: [LogEntry]] = [:]
    private var rolledOverLogKeys: Set<LogBufferKey> = []

    private static let unscopedLogKey = "__flugger_unscoped__"

    private struct LogBufferKey: Hashable {
        let projectKey: String
        let channel: LogChannel
    }

    private struct ActiveRun {
        let id: UUID
        let projectPath: String
        let projectName: String
        let deviceId: String
        let deviceName: String
        let configurationName: String
        let startedAt: Date
    }

    init(
        store: WorkspaceStore = WorkspaceStore(),
        daemon: FlutterDaemon? = nil,
        projectMaintenance: FlutterProjectMaintaining? = nil,
        startDaemon: Bool = true,
        restoreLastProject: Bool = true,
        runnerFactory: @escaping @MainActor (String, String) -> FlutterRunner = { projectPath, deviceId in
            FlutterRunner(projectPath: projectPath, deviceId: deviceId)
        }
    ) {
        self.store = store
        self.daemon = daemon ?? FlutterDaemon()
        self.projectMaintenance = projectMaintenance ?? FlutterProjectMaintenanceService()
        self.runnerFactory = runnerFactory
        snapshot = (try? store.load()) ?? WorkspaceSnapshot()
        recentProjects = snapshot.recentProjects
        sessions = snapshot.sessions

        bindDaemon()
        if restoreLastProject {
            migrateLegacyPreferences()

            if let savedPath = UserDefaultsStore.shared.lastProjectPath {
                try? openProject(at: savedPath, updateSelection: true, promoteInRecents: false)
            }
            if projectPath == nil {
                for project in recentProjects where FileManager.default.fileExists(atPath: project.path) {
                    do {
                        try openProject(at: project.path, updateSelection: true, promoteInRecents: false)
                        break
                    } catch {
                        continue
                    }
                }
            }
        }

        if startDaemon {
            self.daemon.start()
        } else {
            status = "Ready"
        }
    }

    var isAppRunning: Bool { appState.isRunning }
    var canControl: Bool { appState.canControl }
    var canRun: Bool { projectPath != nil && selectedDeviceId != nil && !isAppRunning && !isProjectMaintenanceRunning }
    var canMaintainProject: Bool { projectPath != nil && !isAppRunning && !isProjectMaintenanceRunning }
    var isDaemonRunning: Bool { daemon.isRunning }
    var hasRunningProjects: Bool { projectRunStates.values.contains(where: \.isRunning) }

    func runState(for projectPath: String) -> AppState {
        projectRunStates[projectPath] ?? .idle
    }

    func isProjectRunning(_ projectPath: String) -> Bool {
        runState(for: projectPath).isRunning
    }

    var selectedDevice: Device? {
        devices.first { $0.id == selectedDeviceId }
    }

    var selectedLaunchConfig: LaunchConfig? {
        launchConfigs.first { $0.name == selectedLaunchConfigName }
    }

    var selectedSession: RunSession? {
        guard case let .session(id) = selection else { return nil }
        return sessions.first { $0.id == id }
    }

    var searchText: String {
        get { searchTextByChannel[selectedLogChannel] ?? "" }
        set { searchTextByChannel[selectedLogChannel] = newValue }
    }

    var enabledLogTypes: Set<LogEntryType> {
        enabledLogTypesByChannel[selectedLogChannel] ?? Set(LogEntryType.allCases)
    }

    var filteredLogs: [LogEntry] {
        ConsoleLogTools.filter(logLines, query: searchText, enabledTypes: enabledLogTypes)
    }

    var isCurrentProjectMaintenanceRunning: Bool {
        isProjectMaintenanceRunning && activeMaintenanceProjectPath == projectPath
    }

    var runBlockReason: String? {
        if projectPath == nil { return "Choose a Flutter project first." }
        if isProjectMaintenanceRunning { return "Project maintenance is in progress." }
        if selectedDeviceId == nil { return "Choose a connected device first." }
        if isAppRunning { return "This project is already active." }
        return nil
    }

    var projectMaintenanceBlockReason: String? {
        if projectPath == nil { return "Choose a Flutter project first." }
        if isAppRunning { return "Stop the running app first." }
        if isProjectMaintenanceRunning { return "Project maintenance is already in progress." }
        return nil
    }

    func selectWorkspace(_ newSelection: WorkspaceSelection) {
        selection = newSelection
        guard case let .project(path) = newSelection, path != projectPath else { return }
        do {
            try openProject(at: path, updateSelection: false, promoteInRecents: false)
        } catch {
            status = error.localizedDescription
            addLog(error.localizedDescription, type: .error)
        }
    }

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Project"
        panel.message = "Choose a Flutter project folder"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                do {
                    try self?.openProject(at: url.path, updateSelection: true)
                } catch {
                    self?.status = error.localizedDescription
                    self?.addLog(error.localizedDescription, type: .error)
                }
            }
        }
    }

    func openProject(
        at rawPath: String,
        updateSelection: Bool = true,
        promoteInRecents: Bool = true
    ) throws {
        let path = URL(fileURLWithPath: rawPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        try Self.validateProject(at: path)

        let name = URL(fileURLWithPath: path).lastPathComponent
        let parsedConfigs = LaunchConfig.parse(from: path)
        let configs = parsedConfigs.isEmpty ? LaunchConfig.defaultConfigs() : parsedConfigs
        let existing = recentProjects.first { $0.path == path }

        let consoleKey = LogBufferKey(projectKey: path, channel: .console)
        let isFirstProjectLog = logsByBuffer[consoleKey]?.isEmpty ?? true
        projectPath = path
        projectName = name
        launchConfigs = configs
        refreshVisibleLogs()

        let preferredConfig = existing?.lastConfigurationName ?? UserDefaultsStore.shared.lastLaunchConfigName
        selectedLaunchConfigName = preferredConfig.flatMap { preferred in
            configs.contains { $0.name == preferred } ? preferred : nil
        } ?? configs.first?.name

        let preferredDevice = existing?.lastDeviceId ?? UserDefaultsStore.shared.lastDeviceId
        selectedDeviceId = preferredDevice.flatMap { preferred in
            devices.contains { $0.id == preferred } ? preferred : nil
        }

        UserDefaultsStore.shared.lastProjectPath = path
        UserDefaultsStore.shared.lastLaunchConfigName = selectedLaunchConfigName

        var project = RecentProject(
            path: path,
            displayName: name,
            lastOpenedAt: promoteInRecents ? .now : (existing?.lastOpenedAt ?? .now),
            lastDeviceId: selectedDeviceId,
            lastConfigurationName: selectedLaunchConfigName
        )
        if let existing {
            project.lastDeviceId = existing.lastDeviceId
            project.lastConfigurationName = selectedLaunchConfigName ?? existing.lastConfigurationName
        }
        try persistProject(project, promote: promoteInRecents)

        if updateSelection { selection = .project(path) }
        appState = projectRunStates[path] ?? .idle
        status = projectStatuses[path] ?? "Ready to run \(name)"
        if isFirstProjectLog {
            addLog("Project: \(name)", type: .command, projectPath: path)
        }
    }

    func selectDevice(_ id: String?) {
        selectedDeviceId = id
        UserDefaultsStore.shared.lastDeviceId = id
        updateCurrentProjectPreferences()
    }

    func selectConfiguration(_ name: String?) {
        selectedLaunchConfigName = name
        UserDefaultsStore.shared.lastLaunchConfigName = name
        updateCurrentProjectPreferences()
    }

    func removeRecentProject(_ project: RecentProject) {
        guard !isProjectRunning(project.path) else {
            status = "Stop \(project.displayName) before removing it from recents."
            return
        }
        do {
            try store.removeProject(path: project.path, from: &snapshot)
            recentProjects = snapshot.recentProjects
            if selection == .project(project.path) { selection = .console }
        } catch {
            status = "Could not update recent projects: \(error.localizedDescription)"
        }
    }

    func clearRecentProjects() {
        guard !hasRunningProjects else {
            status = "Stop running projects before clearing recents."
            return
        }
        snapshot.recentProjects.removeAll()
        do {
            try store.save(snapshot)
            recentProjects = []
            if case .project = selection { selection = .console }
        } catch {
            status = "Could not clear recent projects: \(error.localizedDescription)"
        }
    }

    func revealProject(_ project: RecentProject) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
    }

    func runApp() {
        guard canRun, let projectPath, let device = selectedDevice else { return }

        showLiveLogs(.console, for: projectPath)

        let configName = selectedLaunchConfig?.displayName ?? "Debug"
        let runID = UUID()
        activeRunsByProject[projectPath] = ActiveRun(
            id: runID,
            projectPath: projectPath,
            projectName: projectName,
            deviceId: device.id,
            deviceName: device.displayName,
            configurationName: configName,
            startedAt: .now
        )

        let newRunner = runnerFactory(projectPath, device.id)
        newRunner.onLogOutput = { [weak self] message, type in
            self?.addLog(message, type: type, projectPath: projectPath)
        }
        newRunner.onCompletion = { [weak self] outcome in
            self?.finalizeActiveRun(for: projectPath, runID: runID, outcome: outcome)
        }

        var cancellables = Set<AnyCancellable>()
        newRunner.$appState
            .sink { [weak self, weak newRunner] state in
                guard let self, let newRunner, self.runnersByProject[projectPath] === newRunner else { return }
                self.projectRunStates[projectPath] = state
                if self.projectPath == projectPath { self.appState = state }
            }
            .store(in: &cancellables)
        newRunner.$status
            .sink { [weak self, weak newRunner] status in
                guard let self, let newRunner, self.runnersByProject[projectPath] === newRunner else { return }
                self.projectStatuses[projectPath] = status
                if self.projectPath == projectPath { self.status = status }
            }
            .store(in: &cancellables)

        runnersByProject[projectPath] = newRunner
        runnerCancellablesByProject[projectPath] = cancellables
        selection = .project(projectPath)
        newRunner.start(with: selectedLaunchConfig)
    }

    func stopApp() {
        guard let projectPath else { return }
        runnersByProject[projectPath]?.stop()
    }

    func hotReload() {
        guard let projectPath, let runner = runnersByProject[projectPath] else { return }
        showLiveLogs(.console, for: projectPath)
        runner.hotReload()
    }

    func hotRestart() {
        guard let projectPath, let runner = runnersByProject[projectPath] else { return }
        showLiveLogs(.console, for: projectPath)
        runner.hotRestart()
    }

    func requestCleanAndPubGet() {
        guard canMaintainProject else { return }
        isCleanConfirmationPresented = true
    }

    func pubGet() {
        performProjectMaintenance(.pubGet)
    }

    func cleanAndPubGet() {
        isCleanConfirmationPresented = false
        performProjectMaintenance(.cleanAndPubGet)
    }

    func selectLogChannel(_ channel: LogChannel) {
        guard selectedLogChannel != channel else { return }
        selectedLogChannel = channel
        refreshVisibleLogs()
    }

    func clearLogs() {
        let key = activeLogBufferKey
        logsByBuffer[key] = []
        rolledOverLogKeys.remove(key)
        logLines = []
        let message = "\(selectedLogChannel.label) cleared"
        if let projectPath {
            updateStatus(message, for: projectPath)
        } else {
            status = message
        }
    }

    func toggleFilter(_ type: LogEntryType) {
        var enabledTypes = enabledLogTypes
        if enabledTypes.contains(type) {
            enabledTypes.remove(type)
        } else {
            enabledTypes.insert(type)
        }
        enabledLogTypesByChannel[selectedLogChannel] = enabledTypes
    }

    func copyVisibleLogs() {
        let text = ConsoleLogTools.exportText(filteredLogs)
        guard !text.isEmpty else {
            status = "There is no visible output to copy."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        status = "Copied \(filteredLogs.count) \(selectedLogChannel.label.lowercased()) lines"
    }

    func exportVisibleLogs() {
        let entries = filteredLogs
        guard !entries.isEmpty else {
            status = "There is no visible output to export."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(projectName)-\(selectedLogChannel.rawValue).log"
        panel.prompt = "Export"
        let channelName = selectedLogChannel.label.lowercased()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let text = ConsoleLogTools.exportText(entries)
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                Task { @MainActor in self?.status = "Exported \(entries.count) \(channelName) lines" }
            } catch {
                Task { @MainActor in self?.status = "Export failed: \(error.localizedDescription)" }
            }
        }
    }

    func refreshDevices() { daemon.refreshDevices() }

    func retryDaemon() {
        status = "Restarting Flutter tools…"
        daemon.restart()
    }

    func clearHistory() {
        do {
            try store.clearHistory(in: &snapshot)
            sessions = []
            if case .session = selection { selection = .console }
            status = "Run history cleared"
        } catch {
            status = "Could not clear history: \(error.localizedDescription)"
        }
    }

    func deleteSession(_ session: RunSession) {
        do {
            try store.removeSession(id: session.id, from: &snapshot)
            sessions = snapshot.sessions
            if selection == .session(session.id) { selection = .console }
            status = "Run deleted"
        } catch {
            status = "Could not delete run: \(error.localizedDescription)"
        }
    }

    static func validateProject(at path: String, fileManager: FileManager = .default) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WorkspaceValidationError.missingDirectory
        }

        let pubspecPath = URL(fileURLWithPath: path).appendingPathComponent("pubspec.yaml").path
        guard fileManager.fileExists(atPath: pubspecPath) else {
            throw WorkspaceValidationError.missingPubspec
        }
        guard let contents = try? String(contentsOfFile: pubspecPath, encoding: .utf8) else {
            throw WorkspaceValidationError.unreadableProject
        }
        guard contents.range(of: #"(?m)^\s*flutter\s*:"#, options: .regularExpression) != nil else {
            throw WorkspaceValidationError.notFlutterProject
        }
    }

    private func bindDaemon() {
        daemon.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self else { return }
                self.devices = devices.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                if let selectedDeviceId = self.selectedDeviceId,
                   !devices.contains(where: { $0.id == selectedDeviceId }) {
                    self.selectedDeviceId = nil
                    self.status = "The selected device disconnected."
                } else if self.selectedDeviceId == nil,
                          let saved = UserDefaultsStore.shared.lastDeviceId,
                          devices.contains(where: { $0.id == saved }) {
                    self.selectedDeviceId = saved
                }
            }
            .store(in: &daemonCancellables)

        daemon.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                guard let self, !self.isAppRunning, !self.isProjectMaintenanceRunning else { return }
                self.status = running ? "Flutter tools ready" : self.daemon.status
            }
            .store(in: &daemonCancellables)

        daemon.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] daemonStatus in
                guard let self, !self.isAppRunning, !self.isProjectMaintenanceRunning else { return }
                self.status = daemonStatus
            }
            .store(in: &daemonCancellables)

        daemon.onLogOutput = { [weak self] message, type in
            self?.addLog(message, type: type)
        }
    }

    private func migrateLegacyPreferences() {
        guard recentProjects.isEmpty,
              let path = UserDefaultsStore.shared.lastProjectPath,
              FileManager.default.fileExists(atPath: path) else { return }
        let project = RecentProject(
            path: path,
            lastDeviceId: UserDefaultsStore.shared.lastDeviceId,
            lastConfigurationName: UserDefaultsStore.shared.lastLaunchConfigName
        )
        try? persistProject(project)
    }

    private func persistProject(_ project: RecentProject, promote: Bool = true) throws {
        if promote {
            _ = try store.upsert(project, in: &snapshot)
        } else {
            try store.updateProject(project, in: &snapshot)
        }
        recentProjects = snapshot.recentProjects
    }

    private func updateCurrentProjectPreferences() {
        guard let projectPath,
              var project = recentProjects.first(where: { $0.path == projectPath }) else { return }
        project.lastDeviceId = selectedDeviceId
        project.lastConfigurationName = selectedLaunchConfigName
        try? persistProject(project, promote: false)
    }

    private func finalizeActiveRun(for projectPath: String, runID: UUID, outcome: RunOutcome) {
        guard let activeRun = activeRunsByProject[projectPath], activeRun.id == runID else { return }
        activeRunsByProject[projectPath] = nil
        let session = RunSession(
            id: activeRun.id,
            projectPath: activeRun.projectPath,
            projectName: activeRun.projectName,
            deviceId: activeRun.deviceId,
            deviceName: activeRun.deviceName,
            configurationName: activeRun.configurationName,
            startedAt: activeRun.startedAt,
            endedAt: .now,
            outcome: outcome
        )

        do {
            try store.append(session, to: &snapshot)
            sessions = snapshot.sessions
        } catch {
            addLog(
                "Could not save run history: \(error.localizedDescription)",
                type: .error,
                projectPath: activeRun.projectPath
            )
        }
    }

    private func performProjectMaintenance(_ operation: FlutterProjectMaintenanceOperation) {
        guard let projectPath, canMaintainProject else {
            if let projectMaintenanceBlockReason { status = projectMaintenanceBlockReason }
            return
        }

        showLiveLogs(.output, for: projectPath)
        isProjectMaintenanceRunning = true
        activeMaintenanceProjectPath = projectPath
        updateStatus("Running \(operation.displayName)…", for: projectPath)
        let startedAt = Date.now.formatted(date: .abbreviated, time: .standard)
        addLog(
            "\(operation.displayName) — \(projectName) — \(startedAt)",
            type: .command,
            projectPath: projectPath,
            channel: .output
        )
        let started = projectMaintenance.run(
            operation,
            projectPath: projectPath,
            onOutput: { [weak self] message, type in
                self?.addLog(message, type: type, projectPath: projectPath, channel: .output)
            },
            completion: { [weak self] outcome in
                guard let self else { return }
                self.isProjectMaintenanceRunning = false
                self.activeMaintenanceProjectPath = nil
                switch outcome {
                case .succeeded:
                    self.updateStatus("\(operation.displayName) completed", for: projectPath)
                    self.addLog(
                        "\(operation.displayName) completed",
                        type: .info,
                        projectPath: projectPath,
                        channel: .output
                    )
                case let .failed(command, exitCode):
                    self.updateStatus("\(operation.displayName) failed", for: projectPath)
                    self.addLog(
                        "\(command) exited with code \(exitCode)",
                        type: .error,
                        projectPath: projectPath,
                        channel: .output
                    )
                case let .launchFailed(message):
                    self.updateStatus("Could not start \(operation.displayName)", for: projectPath)
                    self.addLog(message, type: .error, projectPath: projectPath, channel: .output)
                }
            }
        )

        if !started {
            isProjectMaintenanceRunning = false
            activeMaintenanceProjectPath = nil
            updateStatus("Project maintenance is already in progress.", for: projectPath)
            addLog(
                "Project maintenance is already in progress.",
                type: .error,
                projectPath: projectPath,
                channel: .output
            )
        }
    }

    private func updateStatus(_ newStatus: String, for projectPath: String) {
        projectStatuses[projectPath] = newStatus
        if self.projectPath == projectPath {
            status = newStatus
        }
    }

    private func showLiveLogs(_ channel: LogChannel, for projectPath: String) {
        selection = .project(projectPath)
        selectLogChannel(channel)
    }

    func addLog(
        _ message: String,
        type: LogEntryType = .info,
        projectPath targetProjectPath: String? = nil,
        channel: LogChannel = .console
    ) {
        let key = LogBufferKey(
            projectKey: targetProjectPath ?? activeProjectLogKey,
            channel: channel
        )
        var entries = logsByBuffer[key] ?? []

        if entries.count >= Self.maximumLogEntries {
            entries.removeFirst(entries.count - Self.maximumLogEntries + 1)
            if !rolledOverLogKeys.contains(key) {
                rolledOverLogKeys.insert(key)
                entries.append(LogEntry(text: rolloverMessage(for: key), type: .info))
                if entries.count >= Self.maximumLogEntries { entries.removeFirst() }
            }
        }
        entries.append(LogEntry(text: message, type: type))
        logsByBuffer[key] = entries
        trimLogBuffersToGlobalLimit()

        refreshVisibleLogs()
    }

    private var activeProjectLogKey: String {
        projectPath ?? Self.unscopedLogKey
    }

    private var activeLogBufferKey: LogBufferKey {
        LogBufferKey(projectKey: activeProjectLogKey, channel: selectedLogChannel)
    }

    private func refreshVisibleLogs() {
        logLines = logsByBuffer[activeLogBufferKey] ?? []
    }

    private func trimLogBuffersToGlobalLimit() {
        var affectedKeys: Set<LogBufferKey> = []

        while totalLogCount > Self.maximumLogEntries, let key = oldestLogKey {
            logsByBuffer[key]?.removeFirst()
            affectedKeys.insert(key)
        }

        for key in affectedKeys where !rolledOverLogKeys.contains(key) {
            rolledOverLogKeys.insert(key)
            logsByBuffer[key, default: []].append(
                LogEntry(text: rolloverMessage(for: key), type: .info)
            )
        }

        while totalLogCount > Self.maximumLogEntries, let key = oldestLogKey {
            logsByBuffer[key]?.removeFirst()
        }
    }

    private var totalLogCount: Int {
        logsByBuffer.values.reduce(0) { $0 + $1.count }
    }

    private var oldestLogKey: LogBufferKey? {
        logsByBuffer
            .compactMap { key, entries in entries.first.map { (key, $0.timestamp) } }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func rolloverMessage(for key: LogBufferKey) -> String {
        "Older \(key.channel.label.lowercased()) output was removed after reaching 10,000 lines."
    }
}
