import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var sourceControlViewModel: SourceControlViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @SceneStorage("workspaceMode") private var workspaceModeRawValue = WorkspaceMode.console.rawValue
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }
    private var nextTheme: ThemeMode { selectedTheme.next }
    private var workspaceMode: WorkspaceMode {
        get { WorkspaceMode(rawValue: workspaceModeRawValue) ?? .console }
        nonmutating set { workspaceModeRawValue = newValue.rawValue }
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
