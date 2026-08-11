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

    var next: ThemeMode {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }
}

@main
struct FluggerApp: App {
    @StateObject private var viewModel = WorkspaceViewModel()
    @StateObject private var keyboardShortcuts = KeyboardShortcutStore()
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue
    @AppStorage(PreferenceKeys.appFontSize) private var appFontSize = AppFontSizing.defaultSize

    private var selectedTheme: ThemeMode { ThemeMode(rawValue: themeMode) ?? .system }

    var body: some Scene {
        WindowGroup("Flugger", id: "workspace") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 820, minHeight: 520)
                .preferredColorScheme(selectedTheme.colorScheme)
                .workbenchAppFontSize(appFontSize)
                .environmentObject(keyboardShortcuts)
        }
        .defaultSize(width: 1120, height: 1440)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            SidebarCommands()
            WorkbenchCommands(
                viewModel: viewModel,
                terminalWorkspaces: viewModel.terminalWorkspaces,
                keyboardShortcuts: keyboardShortcuts,
                appFontSize: $appFontSize
            )
        }

        Settings {
            SettingsView(viewModel: viewModel, keyboardShortcuts: keyboardShortcuts)
                .preferredColorScheme(selectedTheme.colorScheme)
                .workbenchAppFontSize(appFontSize)
        }
    }
}

private struct WorkbenchCommands: Commands {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var terminalWorkspaces: TerminalWorkspaceManager
    @ObservedObject var keyboardShortcuts: KeyboardShortcutStore
    @Binding var appFontSize: Double

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()

            Button("Increase App Font Size") {
                appFontSize = AppFontSizing.increased(appFontSize)
            }
            .workbenchShortcut(keyboardShortcuts.binding(for: .increaseAppFontSize))
            .disabled(appFontSize >= AppFontSizing.maximumSize)

            Button("Decrease App Font Size") {
                appFontSize = AppFontSizing.decreased(appFontSize)
            }
            .workbenchShortcut(keyboardShortcuts.binding(for: .decreaseAppFontSize))
            .disabled(appFontSize <= AppFontSizing.minimumSize)
        }

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

        CommandMenu("Terminal") {
            Button(
                terminalWorkspaces.isVisible(for: viewModel.projectPath) ? "Hide Terminal" : "Show Terminal",
                systemImage: "terminal",
                action: viewModel.toggleTerminal
            )
            .workbenchShortcut(keyboardShortcuts.binding(for: .toggleTerminal))
            .disabled(!viewModel.isTerminalAvailable)
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
