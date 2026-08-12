import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let sourceControlViewModel: SourceControlViewModel
    @ObservedObject private var terminalWorkspaces: TerminalWorkspaceManager
    @EnvironmentObject private var keyboardShortcuts: KeyboardShortcutStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isSourceControlSheetPresented = false
    @State private var showSDKInfoPopover = false
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }
    private var nextTheme: ThemeMode { selectedTheme.next }
    private var isTerminalVisible: Bool {
        terminalWorkspaces.isVisible(for: viewModel.projectPath)
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
                    LiveWorkspaceView(
                        viewModel: viewModel,
                        sourceControlViewModel: sourceControlViewModel,
                        isSourceControlSheetPresented: $isSourceControlSheetPresented
                    )
                    .navigationTitle(viewModel.projectName)
                    .navigationSubtitle(viewModel.projectPath?.abbreviatingWithTildeInPath ?? "")
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
                    showSDKInfoPopover = true
                } label: {
                    Label("Flutter SDK Info", systemImage: "info.circle")
                        .labelStyle(.iconOnly)
                }
                .workbenchTooltip("Flutter SDK Info", placement: .below)
                .accessibilityLabel("Flutter SDK Info")

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
        .onReceive(NotificationCenter.default.publisher(for: .showSourceControlSheet)) { _ in
            isSourceControlSheetPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFlutterSDKInfo)) { _ in
            showSDKInfoPopover = true
        }
        .sheet(isPresented: $showSDKInfoPopover) {
            FlutterSDKInfoSheet(
                service: viewModel.sdkInfoService,
                onOpenLink: viewModel.openLink(_:)
            )
        }
        .sheet(isPresented: $isSourceControlSheetPresented) {
            VStack(spacing: 0) {
                HStack {
                    Text("Source Control")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        isSourceControlSheetPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close Source Control")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                Divider()
                SourceControlView(viewModel: sourceControlViewModel)
            }
            .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 700)
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
}
