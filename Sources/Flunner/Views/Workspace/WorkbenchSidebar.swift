import AppKit
import SwiftUI

struct WorkbenchSidebar: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var projectSearchText = ""

    private var filteredProjects: [RecentProject] {
        let query = projectSearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return viewModel.recentProjects }
        return viewModel.recentProjects.filter { project in
            project.displayName.localizedCaseInsensitiveContains(query) ||
            project.path.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section("Projects") {
                projectSearchBar

                ForEach(filteredProjects) { project in
                    let isSelected = viewModel.selection == .project(project.path)
                    Button {
                        viewModel.selectWorkspace(.project(project.path))
                    } label: {
                        SidebarProjectRow(
                            project: project,
                            icon: viewModel.projectIcons[project.path],
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
                        .workbenchFont(.caption)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                        .padding(.vertical, WorkbenchSpacing.xs)
                } else {
                    ForEach(viewModel.sessions) { session in
                        let isSelected = viewModel.selection == .session(session.id)
                        SidebarSessionItem(
                            session: session,
                            isSelected: isSelected,
                            onSelect: { viewModel.selectWorkspace(.session(session.id)) },
                            onDelete: { viewModel.deleteSession(session) }
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollIndicators(.never)
    }

    private var projectSearchBar: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WorkbenchColor.textSecondary)
            WorkbenchSearchField(text: $projectSearchText, placeholder: "Filter projects")
            if !projectSearchText.isEmpty {
                Button {
                    projectSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(WorkbenchColor.textSecondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, WorkbenchSpacing.compact)
        .frame(height: 26)
        .background(WorkbenchColor.background, in: RoundedRectangle(cornerRadius: WorkbenchRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: WorkbenchRadius.large)
                .stroke(WorkbenchColor.divider, lineWidth: 1)
        }
        .padding(.bottom, WorkbenchSpacing.medium)
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
    let icon: NSImage?
    let isCurrent: Bool
    let runState: AppState

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: isCurrent ? "folder.fill" : "folder")
                        .foregroundStyle(isCurrent ? WorkbenchColor.accent : WorkbenchColor.textSecondary)
                }
            }
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .workbenchFont(.body, weight: isCurrent ? .semibold : .regular)
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .lineLimit(1)
                Text(project.path.abbreviatingWithTildeInPath)
                    .workbenchFont(.caption)
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
                    .workbenchFont(.body)
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .lineLimit(1)
                Text(session.startedAt, format: .relative(presentation: .named))
                    .workbenchFont(.caption)
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

private struct SidebarSessionItem: View {
    let session: RunSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            Button(action: onSelect) {
                SidebarSessionRow(session: session)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .help("Show run from \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(WorkbenchColor.error)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .accessibilityHidden(!isHovered)
            .accessibilityLabel("Delete run")
            .workbenchTooltip("Delete run")
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .listRowBackground(SidebarSelectionBackground(isSelected: isSelected))
        .contextMenu {
            Button("Delete Run", role: .destructive, action: onDelete)
        }
    }
}

extension String {
    var abbreviatingWithTildeInPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard hasPrefix(home) else { return self }
        return "~" + dropFirst(home.count)
    }
}

struct WorkbenchSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.drawsBackground = false
        field.focusRingType = .none
        field.isBordered = false
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
