import SwiftUI

struct WorkbenchSidebar: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        List {
            Section("Projects") {
                ForEach(viewModel.recentProjects) { project in
                    let isSelected = viewModel.selection == .project(project.path)
                    Button {
                        viewModel.selectWorkspace(.project(project.path))
                    } label: {
                        SidebarProjectRow(
                            project: project,
                            isCurrent: project.path == viewModel.projectPath,
                            runState: viewModel.runState(for: project.path)
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(SidebarSelectionBackground(isSelected: isSelected))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .help("Open \(project.displayName)")
                        .contextMenu {
                            Button("Open") { viewModel.selectWorkspace(.project(project.path)) }
                            Button("Reveal in Finder") { viewModel.revealProject(project) }
                            Divider()
                            Button("Remove from Recents", role: .destructive) {
                                viewModel.removeRecentProject(project)
                            }
                            .disabled(viewModel.isProjectRunning(project.path))
                        }
                }

                Button(action: viewModel.chooseProject) {
                    Label("Open Project…", systemImage: "folder.badge.plus")
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }

            Section("Run History") {
                if viewModel.sessions.isEmpty {
                    Text("Runs appear here after they end.")
                        .font(WorkbenchFont.caption)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                        .padding(.vertical, WorkbenchSpacing.xs)
                } else {
                    ForEach(viewModel.sessions) { session in
                        let isSelected = viewModel.selection == .session(session.id)
                        Button {
                            viewModel.selectWorkspace(.session(session.id))
                        } label: {
                            SidebarSessionRow(session: session)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(SidebarSelectionBackground(isSelected: isSelected))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        .help("Show run from \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Flugger")
    }
}

private struct SidebarSelectionBackground: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous)
                .fill(WorkbenchColor.accentSoft)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(WorkbenchColor.accent)
                        .frame(width: 3)
                        .padding(.vertical, WorkbenchSpacing.xs)
                }
                .padding(.vertical, 2)
        }
    }
}

private struct SidebarProjectRow: View {
    let project: RecentProject
    let isCurrent: Bool
    let runState: AppState

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: isCurrent ? "folder.fill" : "folder")
                .frame(width: 18)
                .foregroundStyle(isCurrent ? WorkbenchColor.accent : WorkbenchColor.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .font(WorkbenchFont.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .lineLimit(1)
                Text(project.path.abbreviatingWithTildeInPath)
                    .font(WorkbenchFont.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: WorkbenchSpacing.xs)

            if runState.isRunning {
                Circle()
                    .fill(runState == .running ? WorkbenchColor.success : WorkbenchColor.warning)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel(runState == .running ? "Running" : "Transitioning")
            } else if runState == .error {
                Circle()
                    .fill(WorkbenchColor.error)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("Run failed")
            }
        }
        .padding(.vertical, WorkbenchSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

private struct SidebarSessionRow: View {
    let session: RunSession

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: session.outcome.systemImage)
                .frame(width: 18)
                .foregroundStyle(outcomeColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(WorkbenchFont.body)
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .lineLimit(1)
                Text(session.startedAt, format: .relative(presentation: .named))
                    .font(WorkbenchFont.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary)
            }
        }
        .padding(.vertical, WorkbenchSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var outcomeColor: Color {
        switch session.outcome {
        case .ended: WorkbenchColor.success
        case .stoppedByUser: WorkbenchColor.textSecondary
        case .failed: WorkbenchColor.error
        case .interrupted: WorkbenchColor.warning
        }
    }
}

private extension String {
    var abbreviatingWithTildeInPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard hasPrefix(home) else { return self }
        return "~" + dropFirst(home.count)
    }
}
