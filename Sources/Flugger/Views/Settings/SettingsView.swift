import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @ObservedObject var keyboardShortcuts: KeyboardShortcutStore
    @AppStorage(PreferenceKeys.themeMode) private var themeMode = ThemeMode.system.rawValue
    @AppStorage(PreferenceKeys.appFontSize) private var appFontSize = AppFontSizing.defaultSize
    @AppStorage(PreferenceKeys.consoleFontSize) private var consoleFontSize = 12.0
    @AppStorage(PreferenceKeys.showTimestamps) private var showTimestamps = true
    @AppStorage(PreferenceKeys.followOutput) private var followOutput = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "Copyright © 2025 Flugger. All rights reserved."
    }

    var body: some View {
        TabView {
            Form {
                Section {
                    HStack(spacing: WorkbenchSpacing.medium) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                            Text("Flugger")
                                .font(.headline)
                            Text("Version \(appVersion) (\(buildNumber))")
                                .workbenchFont(.body)
                                .foregroundStyle(WorkbenchColor.textSecondary)
                            Text(copyright)
                                .workbenchFont(.caption)
                                .foregroundStyle(WorkbenchColor.textSecondary)
                        }
                    }
                    .padding(.vertical, WorkbenchSpacing.xs)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $themeMode) {
                        ForEach(ThemeMode.allCases, id: \.rawValue) { theme in
                            Label(theme.label, systemImage: theme.icon).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("App Font Size")
                        Slider(
                            value: $appFontSize,
                            in: AppFontSizing.minimumSize...AppFontSizing.maximumSize,
                            step: AppFontSizing.step
                        )
                        Text("\(Int(appFontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(WorkbenchColor.textSecondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                Section("Logs") {
                    HStack {
                        Text("Log Font Size")
                        Slider(value: $consoleFontSize, in: 9...20, step: 1)
                        Text("\(Int(consoleFontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(WorkbenchColor.textSecondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                    Toggle("Show timestamps", isOn: $showTimestamps)
                    Toggle("Follow new output", isOn: $followOutput)
                }

                Section {
                    Button("Restore Defaults") {
                        restoreDefaults()
                    }
                } footer: {
                    Text("Resets all General settings to their original values.")
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Recent Projects") {
                    LabeledContent("Stored", value: "\(viewModel.recentProjects.count) of \(WorkspaceStore.recentProjectLimit)")
                    Button("Clear Recent Projects", role: .destructive, action: viewModel.clearRecentProjects)
                        .disabled(viewModel.recentProjects.isEmpty || viewModel.hasRunningProjects)
                }

                Section("Run History") {
                    LabeledContent("Stored", value: "\(viewModel.sessions.count) of \(WorkspaceStore.sessionLimit)")
                    Text("Only project, device, configuration, timing, and outcome metadata is saved. Console and Output text is never stored.")
                        .workbenchFont(.caption)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                    Button("Clear Run History", role: .destructive, action: viewModel.clearHistory)
                        .disabled(viewModel.sessions.isEmpty)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Data", systemImage: "internaldrive") }

            ShortcutSettingsView(keyboardShortcuts: keyboardShortcuts)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 600, height: 500)
        .workbenchAppFontSize(appFontSize)
        .tint(WorkbenchColor.accent)
    }

    private func restoreDefaults() {
        themeMode = ThemeMode.system.rawValue
        appFontSize = AppFontSizing.defaultSize
        consoleFontSize = 12
        showTimestamps = true
        followOutput = true
    }
}

private struct ShortcutSettingsView: View {
    @ObservedObject var keyboardShortcuts: KeyboardShortcutStore

    var body: some View {
        Form {
            Section("Project") {
                ForEach(WorkbenchAction.projectActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            Section("Run") {
                ForEach(WorkbenchAction.runActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            Section("Logs") {
                ForEach(WorkbenchAction.logActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            Section("Terminal") {
                ForEach(WorkbenchAction.terminalActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            Section("Source Control") {
                ForEach(WorkbenchAction.sourceControlActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            Section("Appearance") {
                ForEach(WorkbenchAction.appearanceActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            Section("Tools") {
                ForEach(WorkbenchAction.toolsActions) { action in
                    ShortcutRow(action: action, keyboardShortcuts: keyboardShortcuts)
                }
            }

            if let validationMessage = keyboardShortcuts.validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .workbenchFont(.caption)
                        .foregroundStyle(WorkbenchColor.error)
                }
            }

            Section {
                Button("Restore Default Shortcuts", action: keyboardShortcuts.resetAll)
            } footer: {
                Text("Changes apply immediately. Shortcuts must include Command, Option, or Control and cannot be assigned to more than one action.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRow: View {
    let action: WorkbenchAction
    @ObservedObject var keyboardShortcuts: KeyboardShortcutStore

    private var shortcut: WorkbenchShortcut { keyboardShortcuts.binding(for: action) }

    var body: some View {
        LabeledContent(action.label) {
            Menu {
                Section("Modifiers") {
                    ForEach(ShortcutModifier.displayOrder) { modifier in
                        Button {
                            keyboardShortcuts.toggleModifier(modifier, for: action)
                        } label: {
                            Label(
                                modifier.label,
                                systemImage: shortcut.modifiers.contains(modifier) ? "checkmark" : "circle"
                            )
                        }
                    }
                }

                Divider()
                keyMenu("Letters", keys: ShortcutKey.letters)
                keyMenu("Numbers", keys: ShortcutKey.numbers)
                keyMenu("Symbols", keys: ShortcutKey.symbols)
                keyMenu("Special Keys", keys: ShortcutKey.special)
                Divider()
                Button("Restore \(action.label) Default") {
                    keyboardShortcuts.reset(action)
                }
            } label: {
                Text(shortcut.displayName)
                    .workbenchFont(.body, design: .monospaced)
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .frame(minWidth: 62, minHeight: 32, alignment: .trailing)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("\(action.label) shortcut, \(shortcut.displayName)")
        }
    }

    private func keyMenu(_ title: String, keys: [ShortcutKey]) -> some View {
        Menu(title) {
            ForEach(keys) { key in
                Button {
                    keyboardShortcuts.setKey(key, for: action)
                } label: {
                    if shortcut.key == key {
                        Label(key.displayName, systemImage: "checkmark")
                    } else {
                        Text(key.displayName)
                    }
                }
            }
        }
    }
}
