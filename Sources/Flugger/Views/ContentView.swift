import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }

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
                .help("Appearance: \(selectedTheme.label)")
                .accessibilityLabel("Appearance")
                .accessibilityValue(selectedTheme.label)

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                        .help("Open Settings")
                }
                .help("Open Settings")
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
