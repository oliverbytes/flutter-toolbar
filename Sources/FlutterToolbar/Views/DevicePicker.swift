import SwiftUI

struct DevicePicker: View {
    @ObservedObject var viewModel: ToolbarViewModel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Picker("", selection: $viewModel.selectedDeviceId) {
                Text("Select Device").tag(nil as String?)
                ForEach(viewModel.devices) { device in
                    Text(device.displayName).tag(device.id as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 140)
            .onChange(of: viewModel.selectedDeviceId) { newValue in
                UserDefaultsStore.shared.lastDeviceId = newValue
            }
        }
    }
}