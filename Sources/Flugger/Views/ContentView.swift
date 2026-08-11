import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }
    private var isSidebarVisible: Bool { columnVisibility != .detailOnly }

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
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    columnVisibility = isSidebarVisible ? .detailOnly : .all
                } label: {
                    Label(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
                        .labelStyle(.iconOnly)
                }
                .workbenchTooltip(
                    isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                    placement: .below
                )
                .accessibilityLabel(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    ForEach(ThemeMode.allCases, id: \.rawValue) { theme in
                        Button {
                            themeMode = theme.rawValue
                        } label: {
                            Label(theme.label, systemImage: selectedTheme == theme ? "checkmark" : theme.icon)
                        }
                    }
                } label: {
                    Label("Appearance", systemImage: selectedTheme.icon)
                        .labelStyle(.iconOnly)
                }
                .workbenchTooltip("Appearance: \(selectedTheme.label)", placement: .below)
                .accessibilityLabel("Appearance")
                .accessibilityValue(selectedTheme.label)

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
