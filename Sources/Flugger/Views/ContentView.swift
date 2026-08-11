import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var sourceControlViewModel: SourceControlViewModel
    @ObservedObject private var terminalWorkspaces: TerminalWorkspaceManager
    @EnvironmentObject private var keyboardShortcuts: KeyboardShortcutStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @SceneStorage("workspaceMode") private var workspaceModeRawValue = WorkspaceMode.console.rawValue
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }
    private var nextTheme: ThemeMode { selectedTheme.next }
    private var isTerminalVisible: Bool {
        terminalWorkspaces.isVisible(for: viewModel.projectPath)
    }
    private var workspaceMode: WorkspaceMode {
        get { WorkspaceMode(rawValue: workspaceModeRawValue) ?? .console }
        nonmutating set { workspaceModeRawValue = newValue.rawValue }
    }

    init(viewModel: WorkspaceViewModel, sourceControlViewModel: SourceControlViewModel) {
        self.viewModel = viewModel
        self.sourceControlViewModel = sourceControlViewModel
        terminalWorkspaces = viewModel.terminalWorkspaces
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkbenchSidebar(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            Group {
                if let session = viewModel.selectedSession {
                    SessionDetailView(session: session)
                } else {
                    switch workspaceMode {
                    case .console:
                        LiveWorkspaceView(viewModel: viewModel)
                    case .sourceControl:
                        SourceControlView(viewModel: sourceControlViewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WorkbenchColor.background)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(WorkbenchColor.accent)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if viewModel.selectedSession != nil {
                    Button {
                        if let path = viewModel.projectPath {
                            viewModel.selectWorkspace(.project(path))
                        } else {
                            viewModel.selectWorkspace(.console)
                        }
                    } label: {
                        Label("Back to Live Workspace", systemImage: "chevron.backward")
                    }
                    .help("Return to the live workspace")
                } else {
                    Picker(
                        "Workspace",
                        selection: Binding(
                            get: { workspaceMode },
                            set: { workspaceMode = $0 }
                        )
                    ) {
                        ForEach(WorkspaceMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                    .accessibilityLabel("Workspace View")
                    .accessibilityIdentifier("workspaceModePicker")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: viewModel.toggleTerminal) {
                    Image(systemName: isTerminalVisible ? "terminal.fill" : "terminal")
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary)
                        .frame(width: 20, height: 20)
                }
                .disabled(!viewModel.isTerminalAvailable)
                .workbenchTooltip(terminalToggleHelp, placement: .below)
                .accessibilityLabel(isTerminalVisible ? "Hide Terminal" : "Show Terminal")
                .accessibilityValue(isTerminalVisible ? "Visible" : "Hidden")

                Button {
                    themeMode = nextTheme.rawValue
                } label: {
                    Label("Cycle Appearance", systemImage: selectedTheme.icon)
                        .labelStyle(.iconOnly)
                }
                .workbenchTooltip(
                    "Appearance: \(selectedTheme.label) · Switch to \(nextTheme.label)",
                    placement: .below
                )
                .accessibilityLabel("Cycle appearance")
                .accessibilityValue(selectedTheme.label)
                .accessibilityHint("Switches to \(nextTheme.label) appearance")

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .workbenchTooltip("Open Settings", placement: .below)
                .accessibilityLabel("Settings")
            }
        }
        .onAppear { sourceControlViewModel.setProjectPath(viewModel.projectPath) }
        .onChange(of: viewModel.projectPath) { _, path in
            sourceControlViewModel.setProjectPath(path)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showConsoleWorkspace)) { _ in
            showLiveWorkspace(.console)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSourceControlWorkspace)) { _ in
            showLiveWorkspace(.sourceControl)
        }
        .confirmationDialog(
            "Clean \(viewModel.projectName) and get packages?",
            isPresented: $viewModel.isCleanConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clean + Pub Get", role: .destructive, action: viewModel.cleanAndPubGet)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes generated Flutter build artifacts, then runs flutter pub get. Your source files are not affected.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            terminalWorkspaces.terminateAll()
        }
    }

    private var terminalToggleHelp: String {
        let action = isTerminalVisible ? "Hide Terminal" : "Show Terminal"
        return "\(action) (\(keyboardShortcuts.binding(for: .toggleTerminal).displayName))"
    }

    private func showLiveWorkspace(_ mode: WorkspaceMode) {
        workspaceMode = mode
        if viewModel.selectedSession != nil {
            if let path = viewModel.projectPath {
                viewModel.selectWorkspace(.project(path))
            } else {
                viewModel.selectWorkspace(.console)
            }
        }
    }
}
