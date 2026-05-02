import SwiftUI

struct ControlButtons: View {
    @ObservedObject var viewModel: ToolbarViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            if viewModel.appState == .running || viewModel.appState == .starting || viewModel.appState == .stopping {
                Button(action: { viewModel.stopApp() }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.appState == .stopping)
                .help(viewModel.appState == .stopping ? "Stopping..." : "Stop App")
                .transition(.opacity.combined(with: .scale))
            } else {
                Button(action: { viewModel.runApp() }) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(HUDButtonStyle())
                .disabled(!viewModel.canRun)
                .help("Run App")
                .transition(.opacity.combined(with: .scale))
            }
            
            Button(action: { viewModel.hotReload() }) {
                Image(systemName: "bolt.fill")
            }
            .buttonStyle(HUDButtonStyle())
            .disabled(!viewModel.canControl)
            .help("Hot Reload")
            
            Button(action: { viewModel.hotRestart() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(HUDButtonStyle())
            .disabled(!viewModel.canControl)
            .help("Hot Restart")
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.appState)
    }
}

struct HUDButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(width: 32, height: 32)
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.4))
            .background(configuration.isPressed ? Color.white.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}