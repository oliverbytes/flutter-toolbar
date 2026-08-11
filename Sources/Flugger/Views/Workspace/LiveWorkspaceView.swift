import SwiftUI

struct LiveWorkspaceView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            SetupBar(viewModel: viewModel)
            Divider().overlay(WorkbenchColor.divider)
            ConsoleToolbar(viewModel: viewModel)
            Divider().overlay(WorkbenchColor.divider)
            ConsolePanel(viewModel: viewModel)
            WorkbenchStatusBar(viewModel: viewModel)
        }
        .background(WorkbenchColor.background)
    }
}

private struct SetupBar: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        HStack(spacing: WorkbenchSpacing.compact) {
            deviceMenu
            configurationMenu
            Spacer(minLength: WorkbenchSpacing.small)
            RunControlCluster(viewModel: viewModel)
        }
        .padding(.horizontal, WorkbenchSpacing.medium)
        .padding(.vertical, WorkbenchSpacing.small)
        .background(WorkbenchColor.surface)
    }

    @ViewBuilder
    private var deviceMenu: some View {
        let title = viewModel.selectedDevice?.displayName ?? (viewModel.devices.isEmpty ? "No devices" : "Choose device")
        WorkbenchMenu(title: "Device", value: title, systemImage: viewModel.selectedDevice?.systemImage ?? "display") {
            deviceMenuContent
        }
    }

    @ViewBuilder
    private var deviceMenuContent: some View {
        if viewModel.devices.isEmpty {
            Text("No connected devices")
        }
        ForEach(viewModel.devices) { device in
            Button {
                viewModel.selectDevice(device.id)
            } label: {
                if viewModel.selectedDevice?.id == device.id {
                    Label(device.displayName, systemImage: "checkmark")
                } else {
                    Label(device.displayName, systemImage: device.systemImage)
                }
            }
        }
        Divider()
        Button("Refresh Devices", systemImage: "arrow.clockwise") {
            viewModel.refreshDevices()
        }
    }

    @ViewBuilder
    private var configurationMenu: some View {
        let title = viewModel.selectedLaunchConfig?.displayName ?? "No configuration"
        WorkbenchMenu(title: "Configuration", value: title, systemImage: "slider.horizontal.3") {
            configurationMenuContent
        }
        .disabled(viewModel.launchConfigs.isEmpty || viewModel.isAppRunning)
    }

    @ViewBuilder
    private var configurationMenuContent: some View {
        ForEach(viewModel.launchConfigs) { config in
            Button {
                viewModel.selectConfiguration(config.name)
            } label: {
                if viewModel.selectedLaunchConfig?.name == config.name {
                    Label(config.displayName, systemImage: "checkmark")
                } else {
                    Text(config.displayName)
                }
            }
        }
    }
}

private struct WorkbenchMenu<Content: View>: View {
    let title: String
    let value: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(title: String, value: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: WorkbenchSpacing.small) {
                Image(systemName: systemImage)
                    .foregroundStyle(WorkbenchColor.textSecondary.opacity(0.78))
                Text(value)
                    .workbenchFont(.body, weight: .medium)
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary.opacity(0.7))
            }
            .frame(minWidth: 164, maxWidth: 240, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("\(title): \(value)")
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct RunControlCluster: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @EnvironmentObject private var keyboardShortcuts: KeyboardShortcutStore

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            Button(action: viewModel.requestCleanAndPubGet) {
                Label("Clean + Pub Get", systemImage: "eraser.fill").labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.textSecondary))
            .disabled(!viewModel.canMaintainProject)
            .workbenchTooltip(viewModel.projectMaintenanceBlockReason ?? actionHelp("Clean + Pub Get", action: .cleanAndPubGet))
            .accessibilityLabel("Clean and Pub Get")

            Button(action: viewModel.pubGet) {
                Label("Pub Get", systemImage: "shippingbox.fill").labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.accent.opacity(0.78)))
            .disabled(!viewModel.canMaintainProject)
            .workbenchTooltip(viewModel.projectMaintenanceBlockReason ?? actionHelp("Pub Get", action: .pubGet))
            .accessibilityLabel("Pub Get")

            Divider()
                .frame(height: 16)
                .padding(.horizontal, WorkbenchSpacing.xs)

            Button(action: viewModel.hotReload) {
                Label("Hot Reload", systemImage: "bolt.fill").labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.warning))
            .disabled(!viewModel.canControl)
            .workbenchTooltip(actionHelp("Hot Reload", action: .hotReload))
            .accessibilityLabel("Hot Reload")

            Button(action: viewModel.hotRestart) {
                Label("Hot Restart", systemImage: "arrow.triangle.2.circlepath").labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.info))
            .disabled(!viewModel.canControl)
            .workbenchTooltip(actionHelp("Hot Restart", action: .hotRestart))
            .accessibilityLabel("Hot Restart")

            if viewModel.isAppRunning {
                Button(action: viewModel.stopApp) {
                    Label(viewModel.appState == .stopping ? "Stopping…" : "Stop", systemImage: "stop.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.error))
                .disabled(viewModel.appState == .stopping)
                .workbenchTooltip(actionHelp("Stop", action: .stop))
                .accessibilityLabel(viewModel.appState == .stopping ? "Stopping" : "Stop")
            } else {
                Button(action: viewModel.runApp) {
                    Label("Run", systemImage: "play.fill").labelStyle(.iconOnly)
                }
                .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.success))
                .disabled(!viewModel.canRun)
                .workbenchTooltip(viewModel.runBlockReason ?? actionHelp("Run", action: .run))
                .accessibilityLabel("Run")
            }
        }
    }

    private func actionHelp(_ title: String, action: WorkbenchAction) -> String {
        "\(title) (\(keyboardShortcuts.binding(for: action).displayName))"
    }
}
