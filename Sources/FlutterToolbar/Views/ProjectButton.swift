import SwiftUI

struct ProjectButton: View {
    @ObservedObject var viewModel: ToolbarViewModel
    
    var body: some View {
        Button(action: { viewModel.selectProject() }) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.secondary)
                Text(viewModel.projectName)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(ProjectButtonStyle())
        .help("Select Flutter Project")
    }
}

struct ProjectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}