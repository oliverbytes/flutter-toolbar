import AppKit
import SwiftUI

struct SourceControlView: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @State private var isBranchPopoverPresented = false
    @State private var prompt: SourceControlPrompt?

    var body: some View {
        VStack(spacing: 0) {
            RepositoryHeader(
                viewModel: viewModel,
                isBranchPopoverPresented: $isBranchPopoverPresented,
                prompt: $prompt
            )
            Divider().overlay(WorkbenchColor.divider)

            if let operation = viewModel.snapshot?.operation {
                OperationBanner(operation: operation, viewModel: viewModel)
                Divider().overlay(WorkbenchColor.divider)
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, dismiss: viewModel.dismissError)
                Divider().overlay(WorkbenchColor.divider)
            }

            content
        }
        .background(WorkbenchColor.background)
        .accessibilityIdentifier("sourceControlWorkspace")
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshAfterActivation()
        }
        .sheet(item: $prompt) { prompt in
            SourceControlPromptSheet(prompt: prompt, viewModel: viewModel)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { viewModel.confirmation != nil },
                set: { if !$0 { viewModel.confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(confirmationButtonTitle, role: confirmationRole, action: viewModel.confirmPendingAction)
            Button("Cancel", role: .cancel) { viewModel.confirmation = nil }
        } message: {
            Text(confirmationMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isRepositoryMissing {
            ContentUnavailableView {
                Label("Source Control Isn’t Set Up", systemImage: "arrow.triangle.branch")
            } description: {
                Text("Initialize a Git repository in this Flutter project to track changes and create commits.")
            } actions: {
                Button("Initialize Repository", action: viewModel.initializeRepository)
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(WorkbenchColor.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.snapshot == nil {
            ContentUnavailableView {
                Label("Choose a Project", systemImage: "folder")
            } description: {
                Text("Open a Flutter project to see its repository changes.")
            }
            .foregroundStyle(WorkbenchColor.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                SourceControlNavigator(viewModel: viewModel, prompt: $prompt)
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 520)
                DiffDetailView(viewModel: viewModel)
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var confirmationTitle: String {
        switch viewModel.confirmation {
        case let .discard(files): files.count == 1 ? "Discard Changes to \(files[0].file.displayName)?" : "Discard Changes to \(files.count) Files?"
        case let .trash(files): files.count == 1 ? "Move \(files[0].file.displayName) to Trash?" : "Move \(files.count) Files to Trash?"
        case let .deleteBranch(name): "Delete \(name)?"
        case let .merge(name): "Merge \(name) into \(viewModel.currentBranch)?"
        case let .rebase(name): "Rebase \(viewModel.currentBranch) onto \(name)?"
        case let .dropStash(stash): "Delete \(stash.reference)?"
        case let .revert(commit): "Revert \(commit.shortSHA)?"
        case let .abort(operation): "Abort \(operation.rawValue.capitalized)?"
        case .amend: "Amend the Latest Commit?"
        case nil: "Confirm Source Control Action"
        }
    }

    private var confirmationButtonTitle: String {
        switch viewModel.confirmation {
        case .discard: "Discard Changes"
        case .trash: "Move to Trash"
        case .deleteBranch: "Delete Branch"
        case .merge: "Merge Branch"
        case .rebase: "Rebase Branch"
        case .dropStash: "Delete Stash"
        case .revert: "Revert Commit"
        case .abort: "Abort Operation"
        case .amend: "Amend Commit"
        case nil: "Continue"
        }
    }

    private var confirmationRole: ButtonRole? {
        switch viewModel.confirmation {
        case .discard, .trash, .deleteBranch, .dropStash, .revert, .abort, .amend: .destructive
        case .merge, .rebase, nil: nil
        }
    }

    private var confirmationMessage: String {
        switch viewModel.confirmation {
        case .discard: "Git will restore the selected tracked files. These working changes cannot be recovered by Flugger."
        case .trash: "The selected untracked files will be moved to the Trash and can be recovered from Finder."
        case .deleteBranch: "Only fully merged local branches can be deleted. Remote branches are not affected."
        case .merge: "Git will merge the selected branch without opening an editor. Conflicts remain in the workspace for you to resolve."
        case .rebase: "Git will replay the current branch onto the selected branch. Conflicts remain in the workspace for you to resolve."
        case .dropStash: "The stash will be permanently removed."
        case .revert: "Git will create a new commit that reverses this commit. Existing history will not be rewritten."
        case .abort: "Git will stop the in-progress operation and restore its pre-operation state."
        case .amend: "This replaces the latest commit and rewrites its commit ID. If it was already pushed, a normal push will be rejected; Flugger never force-pushes."
        case nil: "Review the action before continuing."
        }
    }
}

private struct RepositoryHeader: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @Binding var isBranchPopoverPresented: Bool
    @Binding var prompt: SourceControlPrompt?

    var body: some View {
        HStack(spacing: WorkbenchSpacing.compact) {
            Button {
                isBranchPopoverPresented.toggle()
            } label: {
                HStack(spacing: WorkbenchSpacing.small) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(viewModel.currentBranch)
                        .workbenchFont(.body, weight: .semibold)
                        .lineLimit(1)
                    if let snapshot = viewModel.snapshot, snapshot.ahead > 0 || snapshot.behind > 0 {
                        Text(syncSummary(snapshot))
                            .workbenchFont(.caption, design: .monospaced)
                            .foregroundStyle(WorkbenchColor.textSecondary)
                    }
                    Image(systemName: "chevron.down")
                        .workbenchFont(.caption)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                }
                .frame(minHeight: 32)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $isBranchPopoverPresented, arrowEdge: .bottom) {
                BranchPopover(viewModel: viewModel, prompt: $prompt, isPresented: $isBranchPopoverPresented)
            }
            .help("Switch or manage branches")

            Text(viewModel.repositoryName)
                .workbenchFont(.caption)
                .foregroundStyle(WorkbenchColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: WorkbenchSpacing.small)

            if let activity = viewModel.activity.label {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(activity)
                Text(activity)
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary)
                    .lineLimit(1)
            }

            Button(action: viewModel.fetch) {
                Label("Fetch", systemImage: "arrow.down.circle")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Fetch")
            .workbenchTooltip("Fetch from Remotes")
            .disabled(viewModel.snapshot?.remotes.isEmpty != false || viewModel.isBusy)

            Button(action: viewModel.pull) {
                Label("Pull", systemImage: "arrow.down.to.line")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Pull")
            .workbenchTooltip("Pull Fast-Forward Changes")
            .disabled(!viewModel.canPull)

            if viewModel.canPublish {
                Button("Publish Branch", action: viewModel.publish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Button(action: viewModel.push) {
                    Label("Push", systemImage: "arrow.up.to.line")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Push")
                .workbenchTooltip("Push Changes")
                .disabled(!viewModel.canPush)
            }

            Button(action: viewModel.refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Refresh Source Control")
            .workbenchTooltip("Refresh Source Control")
            .disabled(viewModel.isBusy)
        }
        .padding(.horizontal, WorkbenchSpacing.medium)
        .padding(.vertical, WorkbenchSpacing.small)
        .background(WorkbenchColor.surface)
    }

    private func syncSummary(_ snapshot: GitRepositorySnapshot) -> String {
        var parts: [String] = []
        if snapshot.ahead > 0 { parts.append("↑\(snapshot.ahead)") }
        if snapshot.behind > 0 { parts.append("↓\(snapshot.behind)") }
        return parts.joined(separator: " ")
    }
}

private struct BranchPopover: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @Binding var prompt: SourceControlPrompt?
    @Binding var isPresented: Bool

    private var localBranches: [GitBranch] { viewModel.branches.filter { !$0.isRemote } }
    private var remoteBranches: [GitBranch] { viewModel.branches.filter(\.isRemote) }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.small) {
            HStack {
                Text("Branches")
                    .workbenchFont(.heading)
                Spacer()
                Button {
                    isPresented = false
                    prompt = .createBranch(startPoint: nil)
                } label: {
                    Label("New Branch", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("New Branch")
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, WorkbenchSpacing.compact)

            List {
                Section("Local") {
                    ForEach(localBranches) { branch in
                        BranchRow(branch: branch)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isPresented = false
                                viewModel.switchBranch(branch)
                            }
                            .contextMenu {
                                if branch.isCurrent {
                                    Button("Rename Branch…") {
                                        isPresented = false
                                        prompt = .renameBranch(currentName: branch.name)
                                    }
                                } else {
                                    Button("Switch to \(branch.name)") {
                                        isPresented = false
                                        viewModel.switchBranch(branch)
                                    }
                                    Button("Merge into \(viewModel.currentBranch)…") {
                                        isPresented = false
                                        viewModel.requestMerge(branch)
                                    }
                                    Button("Rebase \(viewModel.currentBranch) onto \(branch.name)…") {
                                        isPresented = false
                                        viewModel.requestRebase(branch)
                                    }
                                    Divider()
                                    Button("Delete Branch…", role: .destructive) {
                                        isPresented = false
                                        viewModel.requestDeleteBranch(branch)
                                    }
                                }
                            }
                    }
                }

                if !remoteBranches.isEmpty {
                    Section("Remote") {
                        ForEach(remoteBranches) { branch in
                            BranchRow(branch: branch)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isPresented = false
                                    viewModel.switchBranch(branch)
                                }
                                .contextMenu {
                                    Button("Switch to \(branch.name)") {
                                        isPresented = false
                                        viewModel.switchBranch(branch)
                                    }
                                    Button("Merge into \(viewModel.currentBranch)…") {
                                        isPresented = false
                                        viewModel.requestMerge(branch)
                                    }
                                    Button("Rebase \(viewModel.currentBranch) onto \(branch.name)…") {
                                        isPresented = false
                                        viewModel.requestRebase(branch)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(.vertical, WorkbenchSpacing.compact)
        .frame(width: 340, height: 420)
    }
}

private struct BranchRow: View {
    let branch: GitBranch

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : (branch.isRemote ? "cloud" : "circle"))
                .foregroundStyle(branch.isCurrent ? WorkbenchColor.accent : WorkbenchColor.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .workbenchFont(.body, weight: branch.isCurrent ? .semibold : .regular)
                    .lineLimit(1)
                HStack(spacing: WorkbenchSpacing.xs) {
                    Text(branch.shortSHA)
                    if let upstream = branch.upstream { Text("· \(upstream)") }
                }
                .workbenchFont(.caption, design: .monospaced)
                .foregroundStyle(WorkbenchColor.textSecondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, WorkbenchSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(branch.isCurrent ? .isSelected : [])
    }
}

private struct OperationBanner: View {
    let operation: GitRepositoryOperation
    @ObservedObject var viewModel: SourceControlViewModel

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Label(operation.label, systemImage: "exclamationmark.triangle.fill")
                .workbenchFont(.body, weight: .semibold)
                .foregroundStyle(WorkbenchColor.warning)
            Text("Resolve conflicts in your editor, stage the resolved files, then continue.")
                .workbenchFont(.caption)
                .foregroundStyle(WorkbenchColor.textSecondary)
            Spacer()
            Button("Continue", action: viewModel.continueOperation)
                .disabled(viewModel.isBusy || !viewModel.conflicts.isEmpty)
            Button("Abort…", role: .destructive) { viewModel.requestAbort(operation) }
                .disabled(viewModel.isBusy)
        }
        .padding(.horizontal, WorkbenchSpacing.medium)
        .padding(.vertical, WorkbenchSpacing.small)
        .background(WorkbenchColor.warning.opacity(0.08))
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(WorkbenchColor.error)
                .accessibilityHidden(true)
            Text(message)
                .workbenchFont(.caption)
                .foregroundStyle(WorkbenchColor.textPrimary)
                .textSelection(.enabled)
                .lineLimit(3)
            Spacer()
            Button(action: dismiss) {
                Label("Dismiss", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Dismiss Error")
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, WorkbenchSpacing.medium)
        .padding(.vertical, WorkbenchSpacing.small)
        .background(WorkbenchColor.error.opacity(0.08))
    }
}

private struct SourceControlNavigator: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @Binding var prompt: SourceControlPrompt?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Source Control View", selection: $viewModel.selectedSection) {
                ForEach(SourceControlSection.allCases) { section in
                    Text(section.label).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(WorkbenchSpacing.compact)

            Divider().overlay(WorkbenchColor.divider)

            switch viewModel.selectedSection {
            case .changes:
                ChangesNavigator(viewModel: viewModel, prompt: $prompt)
            case .history:
                HistoryNavigator(viewModel: viewModel, prompt: $prompt)
            }
        }
        .background(WorkbenchColor.surface)
    }
}

private struct ChangesNavigator: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @Binding var prompt: SourceControlPrompt?
    @FocusState private var isCommitEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.small) {
                Text("Commit Message")
                    .workbenchFont(.caption, weight: .semibold)
                    .foregroundStyle(WorkbenchColor.textSecondary)
                TextEditor(text: $viewModel.commitMessage)
                    .workbenchFont(.body)
                    .focused($isCommitEditorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(WorkbenchSpacing.small)
                    .frame(minHeight: 72, maxHeight: 108)
                    .background(
                        RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous)
                            .fill(WorkbenchColor.background)
                            .stroke(WorkbenchColor.divider)
                    )
                    .accessibilityLabel("Commit Message")
                    .accessibilityIdentifier("sourceControlCommitMessage")

                HStack {
                    Button("Commit Staged Changes", action: viewModel.commit)
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canCommit)
                        .accessibilityIdentifier("sourceControlCommitButton")
                    Menu {
                        Button("Amend Last Commit…", action: viewModel.requestAmend)
                            .disabled(!viewModel.canAmend)
                    } label: {
                        Label("More Commit Actions", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("More Commit Actions")
                    .menuStyle(.borderlessButton)
                    Spacer()
                    if let count = viewModel.snapshot?.changeCount, count > 0 {
                        Text("\(count) \(count == 1 ? "change" : "changes")")
                            .workbenchFont(.caption)
                            .foregroundStyle(WorkbenchColor.textSecondary)
                    }
                }
            }
            .padding(WorkbenchSpacing.compact)

            Divider().overlay(WorkbenchColor.divider)

            if viewModel.snapshot?.changeCount == 0 && viewModel.stashes.isEmpty {
                ContentUnavailableView {
                    Label("No Changes", systemImage: "checkmark.circle")
                } description: {
                    Text("Your working tree matches the latest commit.")
                }
                .foregroundStyle(WorkbenchColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedFiles) {
                    FileChangesSection(
                        title: "Conflicts",
                        selections: viewModel.conflicts,
                        actionTitle: "Stage All Resolved",
                        action: viewModel.stageAll,
                        viewModel: viewModel
                    )
                    FileChangesSection(
                        title: "Staged",
                        selections: viewModel.stagedChanges,
                        actionTitle: "Unstage All",
                        action: viewModel.unstageAll,
                        viewModel: viewModel
                    )
                    FileChangesSection(
                        title: "Changes",
                        selections: viewModel.workingTreeChanges,
                        actionTitle: "Stage All",
                        action: viewModel.stageAll,
                        viewModel: viewModel
                    )
                    FileChangesSection(
                        title: "Untracked",
                        selections: viewModel.untrackedChanges,
                        actionTitle: "Stage All",
                        action: viewModel.stageAll,
                        viewModel: viewModel
                    )

                    if !viewModel.stashes.isEmpty {
                        Section("Stashes") {
                            ForEach(viewModel.stashes) { stash in
                                StashRow(stash: stash, viewModel: viewModel)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .onChange(of: viewModel.selectedFiles) { _, _ in viewModel.selectionChanged() }
            }

            Divider().overlay(WorkbenchColor.divider)

            HStack {
                if !viewModel.selectedFiles.isEmpty {
                    if viewModel.selectedFiles.contains(where: { $0.comparison == .workingTree }) {
                        Button("Stage Selected", action: viewModel.stageSelected)
                            .disabled(viewModel.isBusy)
                    }
                    if viewModel.selectedFiles.contains(where: { $0.comparison == .staged }) {
                        Button("Unstage Selected", action: viewModel.unstageSelected)
                            .disabled(viewModel.isBusy)
                    }
                    Menu("Selected Actions") {
                        let working = Array(viewModel.selectedFiles.filter { $0.comparison == .workingTree && !$0.file.isUntracked })
                        let untracked = Array(viewModel.selectedFiles.filter(\.file.isUntracked))
                        if !working.isEmpty {
                            Button("Discard Selected Changes…", role: .destructive) {
                                viewModel.requestDiscard(working)
                            }
                        }
                        if !untracked.isEmpty {
                            Button("Move Selected Files to Trash…", role: .destructive) {
                                viewModel.requestTrash(untracked)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    Spacer()
                }
                Button {
                    prompt = .createStash
                } label: {
                    Label("Stash Changes", systemImage: "archivebox")
                }
                .disabled(viewModel.snapshot?.hasWorkingTreeChanges != true || viewModel.isBusy)
                Spacer()
                Button("Reveal Repository", action: viewModel.revealRepository)
                    .buttonStyle(.borderless)
            }
            .padding(WorkbenchSpacing.compact)
        }
    }
}

private struct FileChangesSection: View {
    let title: String
    let selections: [GitFileSelection]
    let actionTitle: String
    let action: () -> Void
    @ObservedObject var viewModel: SourceControlViewModel

    var body: some View {
        if !selections.isEmpty {
            Section {
                ForEach(selections) { selection in
                    FileChangeRow(selection: selection)
                        .tag(selection)
                        .contextMenu {
                            if selection.comparison == .staged {
                                Button("Unstage", systemImage: "minus") { viewModel.unstage(selection) }
                            } else {
                                Button("Stage", systemImage: "plus") { viewModel.stage(selection) }
                            }
                            Button("Open in Default Editor", systemImage: "arrow.up.forward.app") {
                                viewModel.openFile(selection)
                            }
                            Divider()
                            if selection.file.isUntracked {
                                Button("Move to Trash…", role: .destructive) { viewModel.requestTrash([selection]) }
                            } else if selection.comparison == .workingTree {
                                Button("Discard Changes…", role: .destructive) { viewModel.requestDiscard([selection]) }
                            }
                        }
                }
            } header: {
                HStack {
                    Text("\(title) · \(selections.count)")
                    Spacer()
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isBusy)
                }
            }
        }
    }
}

private struct FileChangeRow: View {
    let selection: GitFileSelection

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Text(selection.file.kind.abbreviation)
                .workbenchFont(.caption, weight: .semibold, design: .monospaced)
                .foregroundStyle(statusColor)
                .frame(width: 18)
                .accessibilityLabel(selection.file.kind.label)

            VStack(alignment: .leading, spacing: 1) {
                Text(selection.file.displayName)
                    .workbenchFont(.body)
                    .lineLimit(1)
                if !selection.file.parentPath.isEmpty {
                    Text(selection.file.parentPath)
                        .workbenchFont(.caption)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: WorkbenchSpacing.xs)
            if selection.file.isConflicted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(WorkbenchColor.warning)
                    .accessibilityLabel("Conflict")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint(selection.comparison == .staged ? "Shows the staged diff" : "Shows the working tree diff")
    }

    private var statusColor: Color {
        switch selection.file.kind {
        case .added, .untracked: WorkbenchColor.success
        case .deleted, .conflicted: WorkbenchColor.error
        case .renamed, .copied: WorkbenchColor.info
        case .modified, .typeChanged, .unknown: WorkbenchColor.warning
        }
    }
}

private struct StashRow: View {
    let stash: GitStash
    @ObservedObject var viewModel: SourceControlViewModel

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            Image(systemName: "archivebox")
                .foregroundStyle(WorkbenchColor.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(stash.subject)
                    .workbenchFont(.body)
                    .lineLimit(1)
                Text("\(stash.reference) · \(stash.date.formatted(date: .abbreviated, time: .shortened))")
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary)
            }
            Spacer()
            Menu {
                Button("Apply Stash", action: { viewModel.applyStash(stash) })
                Button("Pop Stash", action: { viewModel.popStash(stash) })
                Divider()
                Button("Delete Stash…", role: .destructive) { viewModel.requestDropStash(stash) }
            } label: {
                Label("Stash Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Actions for \(stash.reference)")
            .menuStyle(.borderlessButton)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct HistoryNavigator: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @Binding var prompt: SourceControlPrompt?

    var body: some View {
        if viewModel.commits.isEmpty {
            ContentUnavailableView {
                Label("No Commits", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Commit history will appear after the first commit.")
            }
            .foregroundStyle(WorkbenchColor.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.commits) { commit in
                    Button {
                        viewModel.selectCommit(commit)
                    } label: {
                        CommitRow(commit: commit, isSelected: viewModel.selectedCommit?.id == commit.id)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        viewModel.selectedCommit?.id == commit.id ? WorkbenchColor.accentSoft : Color.clear
                    )
                    .contextMenu {
                        Button("Copy Commit SHA", action: { viewModel.copySHA(commit) })
                        Button("Create Branch Here…") { prompt = .createBranch(startPoint: commit.sha) }
                        Divider()
                        Button("Revert Commit…", role: .destructive) { viewModel.requestRevert(commit) }
                    }
                }

                if viewModel.hasMoreHistory {
                    Button("Load 100 More Commits", action: viewModel.loadMoreHistory)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.isBusy)
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct CommitRow: View {
    let commit: GitCommit
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
            Text(commit.subject)
                .workbenchFont(.body, weight: isSelected ? .semibold : .regular)
                .foregroundStyle(WorkbenchColor.textPrimary)
                .lineLimit(2)
            HStack(spacing: WorkbenchSpacing.xs) {
                Text(commit.shortSHA)
                    .workbenchFont(.caption, design: .monospaced)
                Text("·")
                Text(commit.author)
                Text("·")
                Text(commit.date, format: .relative(presentation: .named))
            }
            .workbenchFont(.caption)
            .foregroundStyle(WorkbenchColor.textSecondary)
            .lineLimit(1)
            if !commit.decorations.isEmpty {
                Text(commit.decorations)
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.info)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, WorkbenchSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DiffDetailView: View {
    @ObservedObject var viewModel: SourceControlViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: WorkbenchSpacing.small) {
                Image(systemName: viewModel.selectedCommit == nil ? "doc.text.magnifyingglass" : "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(WorkbenchColor.textSecondary)
                    .accessibilityHidden(true)
                Text(viewModel.diff?.title ?? "Diff")
                    .workbenchFont(.body, weight: .semibold)
                    .lineLimit(1)
                Spacer()
                if let selection = viewModel.selectedFiles.first, viewModel.selectedFiles.count == 1 {
                    Button("Open File") { viewModel.openFile(selection) }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, WorkbenchSpacing.medium)
            .padding(.vertical, WorkbenchSpacing.small)
            .background(WorkbenchColor.surface)

            Divider().overlay(WorkbenchColor.divider)

            if let diff = viewModel.diff {
                if diff.isBinary {
                    ContentUnavailableView {
                        Label("Binary File", systemImage: "doc.zipper")
                    } description: {
                        Text("Flugger can’t display a text diff for this file.")
                    }
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        if diff.isTruncated {
                            HStack {
                                Label("Diff truncated at 2 MB or 20,000 lines.", systemImage: "exclamationmark.triangle")
                                    .workbenchFont(.caption)
                                    .foregroundStyle(WorkbenchColor.warning)
                                Spacer()
                            }
                            .padding(WorkbenchSpacing.small)
                            .background(WorkbenchColor.warning.opacity(0.08))
                        }
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(diff.lines) { line in
                                    DiffLineRow(line: line)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Select a Change", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Choose one changed file or commit to inspect its unified diff.")
                }
                .foregroundStyle(WorkbenchColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(WorkbenchColor.background)
    }
}

private struct DiffLineRow: View {
    let line: GitDiffLine
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(line.oldLine.map(String.init) ?? "")
                .frame(width: 46, alignment: .trailing)
            Text(line.newLine.map(String.init) ?? "")
                .frame(width: 46, alignment: .trailing)
            Text(marker)
                .frame(width: 22, alignment: .center)
            Text(line.text)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, WorkbenchSpacing.medium)
        }
        .workbenchFont(.caption, design: .monospaced)
        .foregroundStyle(foreground)
        .padding(.vertical, 1)
        .background(background)
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var marker: String {
        switch line.kind {
        case .added: "+"
        case .removed: "−"
        case .header: "@"
        case .context: differentiateWithoutColor ? "·" : ""
        }
    }

    private var foreground: Color {
        switch line.kind {
        case .added: WorkbenchColor.success
        case .removed: WorkbenchColor.error
        case .header: WorkbenchColor.info
        case .context: WorkbenchColor.textPrimary
        }
    }

    private var background: Color {
        switch line.kind {
        case .added: WorkbenchColor.success.opacity(0.08)
        case .removed: WorkbenchColor.error.opacity(0.08)
        case .header: WorkbenchColor.info.opacity(0.07)
        case .context: .clear
        }
    }

    private var accessibilityDescription: String {
        let lineNumber = line.newLine ?? line.oldLine
        let prefix: String
        switch line.kind {
        case .added: prefix = "Added"
        case .removed: prefix = "Removed"
        case .header: prefix = "Diff header"
        case .context: prefix = "Context"
        }
        return [prefix, lineNumber.map { "line \($0)" }, line.text].compactMap { $0 }.joined(separator: ", ")
    }
}

private enum SourceControlPrompt: Identifiable {
    case createBranch(startPoint: String?)
    case renameBranch(currentName: String)
    case createStash

    var id: String {
        switch self {
        case let .createBranch(startPoint): "create:\(startPoint ?? "HEAD")"
        case .renameBranch: "rename"
        case .createStash: "stash"
        }
    }
}

private struct SourceControlPromptSheet: View {
    let prompt: SourceControlPrompt
    @ObservedObject var viewModel: SourceControlViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var includeUntracked = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.medium) {
            Text(title)
                .workbenchFont(.heading)

            Text(description)
                .workbenchFont(.body)
                .foregroundStyle(WorkbenchColor.textSecondary)

            TextField(fieldLabel, text: $value)
                .focused($isFieldFocused)
                .onSubmit(submit)

            if case .createStash = prompt {
                Toggle("Include untracked files", isOn: $includeUntracked)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(actionTitle, action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(requiresValue && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(WorkbenchSpacing.large)
        .frame(width: 440)
        .onAppear {
            if case let .renameBranch(currentName) = prompt { value = currentName }
            isFieldFocused = true
        }
    }

    private var title: String {
        switch prompt {
        case .createBranch: "Create Branch"
        case .renameBranch: "Rename Branch"
        case .createStash: "Stash Changes"
        }
    }

    private var description: String {
        switch prompt {
        case let .createBranch(startPoint):
            startPoint == nil ? "Create and switch to a new branch from HEAD." : "Create and switch to a new branch at this commit."
        case .renameBranch: "Rename the current local branch. The remote branch is not renamed."
        case .createStash: "Save working changes without creating a commit. The message is optional."
        }
    }

    private var fieldLabel: String {
        switch prompt {
        case .createBranch, .renameBranch: "Branch Name"
        case .createStash: "Stash Message (Optional)"
        }
    }

    private var actionTitle: String {
        switch prompt {
        case .createBranch: "Create Branch"
        case .renameBranch: "Rename Branch"
        case .createStash: "Stash Changes"
        }
    }

    private var requiresValue: Bool {
        if case .createStash = prompt { return false }
        return true
    }

    private func submit() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requiresValue || !trimmed.isEmpty else { return }
        switch prompt {
        case let .createBranch(startPoint): viewModel.createBranch(named: trimmed, startPoint: startPoint)
        case .renameBranch: viewModel.renameCurrentBranch(to: trimmed)
        case .createStash: viewModel.createStash(message: trimmed.isEmpty ? nil : trimmed, includeUntracked: includeUntracked)
        }
        dismiss()
    }
}
