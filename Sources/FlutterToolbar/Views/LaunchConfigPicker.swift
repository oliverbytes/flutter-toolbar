import SwiftUI

struct LaunchConfigPicker: View {
    @ObservedObject var viewModel: ToolbarViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hammer")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Picker("", selection: $viewModel.selectedLaunchConfigName) {
                ForEach(viewModel.launchConfigs) { config in
                    Text(config.displayName).tag(config.name as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120)
            .disabled(viewModel.launchConfigs.isEmpty || viewModel.isAppRunning)
        }
    }
}
