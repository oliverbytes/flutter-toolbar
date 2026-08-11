import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct FluggerApp: App {
    @StateObject private var viewModel = WorkspaceViewModel()
    @StateObject private var keyboardShortcuts = KeyboardShortcutStore()
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }

    var body: some Scene {
        WindowGroup("Flugger", id: "workspace") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 820, minHeight: 520)
                .preferredColorScheme(selectedTheme.colorScheme)
                .environmentObject(keyboardShortcuts)
        }
        .defaultSize(width: 1120, height: 1440)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            SidebarCommands()
            WorkbenchCommands(viewModel: viewModel, keyboardShortcuts: keyboardShortcuts)
        }

        Settings {
            SettingsView(viewModel: viewModel, keyboardShortcuts: keyboardShortcuts)
                .preferredColorScheme(selectedTheme.colorScheme)
        }
    }
}

private struct WorkbenchCommands: Commands {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var keyboardShortcuts: KeyboardShortcutStore

    var body: some Commands {
        CommandMenu("Project") {
            Button("Pub Get", systemImage: "shippingbox.fill", action: viewModel.pubGet)
                .workbenchShortcut(keyboardShortcuts.binding(for: .pubGet))
                .disabled(!viewModel.canMaintainProject)

            Button("Clean + Pub Get…", systemImage: "eraser.fill", action: viewModel.requestCleanAndPubGet)
                .workbenchShortcut(keyboardShortcuts.binding(for: .cleanAndPubGet))
                .disabled(!viewModel.canMaintainProject)
        }

        CommandMenu("Run") {
            Button("Run", systemImage: "play.fill", action: viewModel.runApp)
                .workbenchShortcut(keyboardShortcuts.binding(for: .run))
                .disabled(!viewModel.canRun)

            Button("Stop", systemImage: "stop.fill", action: viewModel.stopApp)
                .workbenchShortcut(keyboardShortcuts.binding(for: .stop))
                .disabled(!viewModel.isAppRunning)

            Divider()

            Button("Hot Reload", systemImage: "bolt.fill", action: viewModel.hotReload)
                .workbenchShortcut(keyboardShortcuts.binding(for: .hotReload))
                .disabled(!viewModel.canControl)

            Button("Hot Restart", systemImage: "arrow.triangle.2.circlepath", action: viewModel.hotRestart)
                .workbenchShortcut(keyboardShortcuts.binding(for: .hotRestart))
                .disabled(!viewModel.canControl)
        }

        CommandMenu("Console") {
            Button("Find", systemImage: "magnifyingglass") {
                NotificationCenter.default.post(name: .focusConsoleSearch, object: nil)
            }
            .workbenchShortcut(keyboardShortcuts.binding(for: .focusConsoleSearch))

            Button("Copy Visible Output", systemImage: "doc.on.doc", action: viewModel.copyVisibleLogs)
                .workbenchShortcut(keyboardShortcuts.binding(for: .copyVisibleOutput))
                .disabled(viewModel.filteredLogs.isEmpty)

            Button("Export Visible Output…", systemImage: "square.and.arrow.up", action: viewModel.exportVisibleLogs)
                .workbenchShortcut(keyboardShortcuts.binding(for: .exportVisibleOutput))
                .disabled(viewModel.filteredLogs.isEmpty)

            Divider()

            Button("Clear Console", systemImage: "trash", action: viewModel.clearLogs)
                .workbenchShortcut(keyboardShortcuts.binding(for: .clearConsole))
                .disabled(viewModel.logLines.isEmpty)
        }
    }
}

private extension View {
    func workbenchShortcut(_ shortcut: WorkbenchShortcut) -> some View {
        keyboardShortcut(shortcut.key.keyEquivalent, modifiers: shortcut.eventModifiers)
    }
}
