import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ToolbarViewModel()
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ProjectButton(viewModel: viewModel)
                    .frame(minWidth: 140, maxWidth: 240)

                Divider()
                    .frame(height: 22)

                DevicePicker(viewModel: viewModel)
                    .frame(minWidth: 140, maxWidth: 180)

                Divider()
                    .frame(height: 22)

                LaunchConfigPicker(viewModel: viewModel)
                    .frame(minWidth: 120, maxWidth: 180)

                Divider()
                    .frame(height: 22)

                ControlButtons(viewModel: viewModel)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thickMaterial)
            )
            
            LogPanel(viewModel: viewModel)
        }
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct LogPanel: View {
    @ObservedObject var viewModel: ToolbarViewModel
    @State private var isExpanded = false

    private var visibleLogs: [LogEntry] {
        isExpanded ? Array(viewModel.logLines.suffix(20)) : Array(viewModel.logLines.suffix(3))
    }

    private var panelHeight: CGFloat {
        let lineHeight: CGFloat = 15
        let verticalPadding: CGFloat = 12
        let count = CGFloat(visibleLogs.count)
        return max(count * lineHeight + verticalPadding, 40)
    }

    var body: some View {
        if !viewModel.logLines.isEmpty {
            HStack(spacing: 4) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(visibleLogs) { entry in
                                HStack(spacing: 4) {
                                    if entry.type == .error {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.red)
                                    } else if entry.type == .command {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.blue.opacity(0.7))
                                    }
                                    Text(entry.text)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(logColor(for: entry.type))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .textSelection(.enabled)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: viewModel.logLines.count) { _ in
                        if let last = visibleLogs.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                VStack(spacing: 4) {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .help(isExpanded ? "Collapse logs" : "Expand logs")

                    if isExpanded {
                        Button(action: copyAllLogs) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .help("Copy all logs")

                        Button(action: { viewModel.clearLogs() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .help("Clear logs")
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity, minHeight: panelHeight, maxHeight: panelHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.logLines.count)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }

    private func copyAllLogs() {
        let text = viewModel.logLines.map { $0.text }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func logColor(for type: LogEntryType) -> Color {
        switch type {
        case .error: return .red.opacity(0.9)
        case .command: return .primary.opacity(0.8)
        case .info: return .secondary
        }
    }
}