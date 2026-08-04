import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ToolbarViewModel()
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .help("Quit")

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.thickMaterial)
                )

                LogPanel(viewModel: viewModel)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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

    private var hasLogs: Bool {
        !viewModel.logLines.isEmpty
    }

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if hasLogs {
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
                } else {
                    VStack(spacing: 4) {
                        Text("No logs yet")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Run a Flutter app to see output here.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 4) {
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .disabled(!hasLogs)
                .help(isExpanded ? "Collapse logs" : "Expand logs")

                if isExpanded && hasLogs {
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
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.logLines.count)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
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
