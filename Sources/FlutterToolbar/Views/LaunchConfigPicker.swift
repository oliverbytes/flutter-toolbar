import SwiftUI

struct LaunchConfigPicker: View {
    @ObservedObject var viewModel: ToolbarViewModel

    var body: some View {
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
