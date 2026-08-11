import SwiftUI

extension Notification.Name {
    static let focusConsoleSearch = Notification.Name("focusConsoleSearch")
}

struct ConsoleToolbar: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @EnvironmentObject private var keyboardShortcuts: KeyboardShortcutStore
    @FocusState private var searchFocused: Bool
    @AppStorage(PreferenceKeys.followOutput) private var followOutput = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularToolbar
            compactToolbar
        }
        .padding(.horizontal, WorkbenchSpacing.medium)
        .padding(.vertical, WorkbenchSpacing.xs)
        .background(WorkbenchColor.surface)
        .onReceive(NotificationCenter.default.publisher(for: .focusConsoleSearch)) { _ in
            searchFocused = true
        }
    }

    private var regularToolbar: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            searchField.frame(width: 240)

            ForEach(LogEntryType.allCases, id: \.self) { type in
                FilterChip(type: type, selected: viewModel.enabledLogTypes.contains(type)) {
                    viewModel.toggleFilter(type)
                }
            }

            Spacer()
            trailingActions
        }
    }

    private var compactToolbar: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            searchField.frame(minWidth: 140, maxWidth: 220)

            Menu {
                ForEach(LogEntryType.allCases, id: \.self) { type in
                    Button {
                        viewModel.toggleFilter(type)
                    } label: {
                        Label(type.label, systemImage: viewModel.enabledLogTypes.contains(type) ? "checkmark" : type.systemImage)
                    }
                }
            } label: {
                Label("Log Filters", systemImage: "line.3.horizontal.decrease")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
            .menuStyle(.borderlessButton)
            .help("Filter console output")
            .accessibilityLabel("Log Filters")

            Spacer(minLength: 0)
            trailingActions
        }
    }

    private var searchField: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WorkbenchColor.textSecondary)
            TextField("Search console", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(WorkbenchFont.body)
                .focused($searchFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(WorkbenchColor.textSecondary)
                .help("Clear console search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, WorkbenchSpacing.compact)
        .frame(height: 36)
        .background(WorkbenchColor.background, in: RoundedRectangle(cornerRadius: WorkbenchRadius.small))
        .overlay {
            RoundedRectangle(cornerRadius: WorkbenchRadius.small)
                .stroke(searchFocused ? WorkbenchColor.accent : WorkbenchColor.divider, lineWidth: 1)
        }
    }

    private var trailingActions: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            Button {
                followOutput.toggle()
            } label: {
                Label("Follow Output", systemImage: followOutput ? "arrow.down.to.line.compact" : "pause")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle())
            .help(followOutput ? "Following new output" : "Output following paused")
            .accessibilityLabel(followOutput ? "Pause output following" : "Follow new output")

            Button(action: viewModel.copyVisibleLogs) {
                Label("Copy Visible Output", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle())
            .disabled(viewModel.filteredLogs.isEmpty)
            .help(actionHelp("Copy Visible Output", action: .copyVisibleOutput))
            .accessibilityLabel("Copy Visible Output")

            Button(action: viewModel.exportVisibleLogs) {
                Label("Export Visible Output", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle())
            .disabled(viewModel.filteredLogs.isEmpty)
            .help(actionHelp("Export Visible Output", action: .exportVisibleOutput))
            .accessibilityLabel("Export Visible Output")

            Button(action: viewModel.clearLogs) {
                Label("Clear Console", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle())
            .disabled(viewModel.logLines.isEmpty)
            .help(actionHelp("Clear Console", action: .clearConsole))
            .accessibilityLabel("Clear Console")
        }
    }

    private func actionHelp(_ title: String, action: WorkbenchAction) -> String {
        "\(title) (\(keyboardShortcuts.binding(for: action).displayName))"
    }
}

private struct FilterChip: View {
    let type: LogEntryType
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(type.label, systemImage: type.systemImage)
                .font(WorkbenchFont.caption.weight(.medium))
                .foregroundStyle(selected ? WorkbenchColor.textPrimary : WorkbenchColor.textSecondary)
                .padding(.horizontal, WorkbenchSpacing.small)
                .frame(minHeight: 32)
                .background(
                    selected ? WorkbenchColor.accentSoft : .clear,
                    in: Capsule()
                )
                .overlay { Capsule().stroke(WorkbenchColor.divider, lineWidth: selected ? 0 : 1) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "On" : "Off")
    }
}

struct ConsolePanel: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PreferenceKeys.consoleFontSize) private var consoleFontSize = 12.0
    @AppStorage(PreferenceKeys.showTimestamps) private var showTimestamps = true
    @AppStorage(PreferenceKeys.followOutput) private var followOutput = true

    var body: some View {
        HStack(spacing: 0) {
            RunStateSpine(state: viewModel.appState, reduceMotion: reduceMotion)

            Group {
                if viewModel.logLines.isEmpty {
                    ConsoleEmptyState(viewModel: viewModel)
                } else if viewModel.filteredLogs.isEmpty {
                    ContentUnavailableView(
                        "No Matching Output",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Change the search or enable another log type.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(viewModel.filteredLogs) { entry in
                                    ConsoleRow(entry: entry, fontSize: consoleFontSize, showTimestamp: showTimestamps)
                                        .id(entry.id)
                                }
                            }
                            .padding(.horizontal, WorkbenchSpacing.medium)
                            .padding(.vertical, WorkbenchSpacing.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onChange(of: viewModel.logLines.count) { _, _ in
                            guard followOutput, let last = viewModel.filteredLogs.last else { return }
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WorkbenchColor.surface)
        }
    }
}

private struct ConsoleRow: View {
    let entry: LogEntry
    let fontSize: CGFloat
    let showTimestamp: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: WorkbenchSpacing.small) {
            if showTimestamp {
                Text(
                    entry.timestamp,
                    format: .dateTime
                        .hour(.twoDigits(amPM: .omitted))
                        .minute(.twoDigits)
                        .second(.twoDigits)
                        .secondFraction(.fractional(3))
                        .locale(Locale(identifier: "en_US_POSIX"))
                )
                    .foregroundStyle(WorkbenchColor.textSecondary.opacity(0.78))
                    .frame(width: 88, alignment: .leading)
                    .lineLimit(1)
            }

            Image(systemName: entry.type.systemImage)
                .font(.system(size: max(9, fontSize - 2), weight: .semibold))
                .foregroundStyle(typeColor)
                .frame(width: 16)

            Text(entry.text)
                .foregroundStyle(entry.type == .error ? WorkbenchColor.error : WorkbenchColor.textPrimary)
                .textSelection(.enabled)
        }
        .font(WorkbenchFont.console(size: fontSize))
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.type.label), \(entry.text)")
    }

    private var typeColor: Color {
        switch entry.type {
        case .info: WorkbenchColor.textSecondary.opacity(0.5)
        case .error: WorkbenchColor.error
        case .command: WorkbenchColor.accent
        }
    }
}

private struct ConsoleEmptyState: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        if viewModel.projectPath == nil {
            ContentUnavailableView {
                Label("Choose a Flutter Project", systemImage: "folder.badge.plus")
            } description: {
                Text("Open a project to choose a device and start a run.")
            } actions: {
                Button("Open Project…", action: viewModel.chooseProject)
                    .buttonStyle(WorkbenchPrimaryButtonStyle())
            }
        } else if !viewModel.isDaemonRunning {
            ContentUnavailableView {
                Label("Flutter Tools Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(viewModel.status)
            } actions: {
                Button("Retry", action: viewModel.retryDaemon)
                    .buttonStyle(WorkbenchPrimaryButtonStyle())
            }
        } else {
            ContentUnavailableView(
                "Console Ready",
                systemImage: "terminal",
                description: Text(viewModel.runBlockReason ?? "Run the selected project to see live Flutter output.")
            )
        }
    }
}

private struct RunStateSpine: View {
    let state: AppState
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 4)
            .opacity(isTransitioning && pulse ? 0.42 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }

    private var isTransitioning: Bool { state == .starting || state == .stopping }

    private var color: Color {
        switch state {
        case .idle: WorkbenchColor.divider
        case .starting, .stopping: WorkbenchColor.accent
        case .running: WorkbenchColor.success
        case .error: WorkbenchColor.error
        }
    }
}

struct WorkbenchStatusBar: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @AppStorage(PreferenceKeys.consoleFontSize) private var consoleFontSize = 12.0

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(viewModel.status)
                .font(WorkbenchFont.caption.weight(.medium))
                .foregroundStyle(WorkbenchColor.textSecondary)
                .lineLimit(1)
            Spacer()
            if !viewModel.logLines.isEmpty {
                Text("\(viewModel.filteredLogs.count) of \(viewModel.logLines.count) lines")
                    .font(WorkbenchFont.caption.monospacedDigit())
                    .foregroundStyle(WorkbenchColor.textSecondary)
            }

            Button {
                consoleFontSize = max(9, consoleFontSize - 1)
            } label: {
                Label("Decrease Console Font Size", systemImage: "textformat.size.smaller")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle())
            .disabled(consoleFontSize <= 9)
            .help("Decrease console font size")
            .accessibilityLabel("Decrease Console Font Size")

            Button {
                consoleFontSize = min(20, consoleFontSize + 1)
            } label: {
                Label("Increase Console Font Size", systemImage: "textformat.size.larger")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle())
            .disabled(consoleFontSize >= 20)
            .help("Increase console font size")
            .accessibilityLabel("Increase Console Font Size")
        }
        .padding(.horizontal, WorkbenchSpacing.medium)
        .frame(height: 44)
        .background(WorkbenchColor.background)
        .overlay(alignment: .top) { Divider().overlay(WorkbenchColor.divider) }
    }

    private var statusColor: Color {
        switch viewModel.appState {
        case .idle: viewModel.isDaemonRunning ? WorkbenchColor.textSecondary : WorkbenchColor.warning
        case .starting, .stopping: WorkbenchColor.warning
        case .running: WorkbenchColor.success
        case .error: WorkbenchColor.error
        }
    }
}
