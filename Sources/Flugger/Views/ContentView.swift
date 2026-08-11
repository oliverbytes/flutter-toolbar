import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject private var terminalWorkspaces: TerminalWorkspaceManager
    @EnvironmentObject private var keyboardShortcuts: KeyboardShortcutStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }
    private var nextTheme: ThemeMode { selectedTheme.next }
    private var isTerminalVisible: Bool {
        terminalWorkspaces.isVisible(for: viewModel.projectPath)
    }

    init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
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
                    LiveWorkspaceView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WorkbenchColor.background)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(WorkbenchColor.accent)
        .toolbar {
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
