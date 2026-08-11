import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }
    private var nextTheme: ThemeMode { selectedTheme.next }

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
    }
}
