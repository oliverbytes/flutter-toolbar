import SwiftUI

struct EditableLaunchConfig: Identifiable {
    var id: UUID
    var name: String
    var flutterMode: String?
    var program: String?
    var args: [String]
    var toolArgs: [String]
    var deviceId: String?

    init(from config: LaunchConfig) {
        id = config.id
        name = config.name
        flutterMode = config.flutterMode
        program = config.program
        args = config.args
        toolArgs = config.toolArgs
        deviceId = config.deviceId
    }

    init(name: String = "") {
        id = UUID()
        self.name = name
        flutterMode = nil
        program = nil
        args = []
        toolArgs = []
        deviceId = nil
    }

    func toLaunchConfig() -> LaunchConfig {
        LaunchConfig(
            name: name,
            flutterMode: flutterMode.flatMap { $0.isEmpty ? nil : $0 },
            program: program.flatMap { $0.isEmpty ? nil : $0 },
            args: args.filter { !$0.isEmpty },
            toolArgs: toolArgs.filter { !$0.isEmpty },
            deviceId: deviceId.flatMap { $0.isEmpty ? nil : $0 },
            env: nil
        )
    }
}

private struct FormEntry: Identifiable {
    let id: UUID
    let entry: EditableLaunchConfig
    let isNew: Bool
}

struct LaunchConfigEditorSheet: View {
    let projectPath: String
    let initialConfigs: [LaunchConfig]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [EditableLaunchConfig] = []
    @State private var presentedForm: FormEntry?
    @State private var editingIndex: Int?
    @State private var validationMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Launch Configurations")
                    .workbenchFont(.heading)
                Spacer()
                Text(URL(fileURLWithPath: projectPath).appendingPathComponent(".vscode/launch.json").path)
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, WorkbenchSpacing.medium)
            .padding(.vertical, WorkbenchSpacing.medium)

            Divider().overlay(WorkbenchColor.divider)

            if entries.isEmpty {
                VStack(spacing: WorkbenchSpacing.small) {
                    Text("No configurations yet.")
                        .workbenchFont(.body)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 0) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(WorkbenchColor.textSecondary.opacity(0.5))
                                .font(.system(size: 12))
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            ConfigRow(
                                entry: entry,
                                onEdit: { editEntry(at: index) },
                                onDelete: { deleteEntry(at: index) }
                            )
                        }
                        .contextMenu {
                            Button("Edit") { editEntry(at: index) }
                            Divider()
                            Button("Delete", role: .destructive) { deleteEntry(at: index) }
                        }
                    }
                    .onMove { source, destination in
                        entries.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.inset)
            }

            Divider().overlay(WorkbenchColor.divider)

            HStack(spacing: WorkbenchSpacing.small) {
                Button(action: addNewEntry) {
                    Label("Add Configuration", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(WorkbenchColor.accent)
                .accessibilityLabel("Add new launch configuration")

                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, WorkbenchSpacing.medium)
            .padding(.vertical, WorkbenchSpacing.small)
        }
        .frame(width: 580, height: 520)
        .background(WorkbenchColor.background)
        .onAppear {
            entries = initialConfigs.map(EditableLaunchConfig.init)
        }
        .sheet(item: $presentedForm) { form in
            LaunchConfigFormView(entry: form.entry, isNew: form.isNew) { savedEntry in
                if let index = editingIndex {
                    entries[index] = savedEntry
                } else {
                    entries.append(savedEntry)
                }
                presentedForm = nil
                editingIndex = nil
                validationMessage = nil
            } onCancel: {
                presentedForm = nil
                editingIndex = nil
            }
            .frame(width: 480, height: 540)
        }
    }

    private func addNewEntry() {
        editingIndex = nil
        let entry = EditableLaunchConfig()
        presentedForm = FormEntry(id: entry.id, entry: entry, isNew: true)
    }

    private func editEntry(at index: Int) {
        editingIndex = index
        let entry = entries[index]
        presentedForm = FormEntry(id: entry.id, entry: entry, isNew: false)
    }

    private func deleteEntry(at index: Int) {
        entries.remove(at: index)
    }

    private func save() {
        let uniqueNames = Set(entries.map { $0.name.trimmingCharacters(in: .whitespaces) })
        if uniqueNames.count != entries.count {
            validationMessage = "Each configuration must have a unique name."
            return
        }
        if entries.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
            validationMessage = "Each configuration must have a name."
            return
        }

        do {
            let dartConfigs = entries.map { $0.toLaunchConfig() }
            try LaunchConfig.saveConfigs(dartConfigs: dartConfigs, to: projectPath)
            onSave()
            dismiss()
        } catch {
            validationMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}

private struct ConfigRow: View {
    let entry: EditableLaunchConfig
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: WorkbenchSpacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .workbenchFont(.body, weight: .medium)
                    .foregroundStyle(WorkbenchColor.textPrimary)
                    .lineLimit(1)
                if let subdetail = subdetail {
                    Text(subdetail)
                        .workbenchFont(.caption)
                        .foregroundStyle(WorkbenchColor.textSecondary)
                        .lineLimit(1)
                }
            }

            if let mode = entry.flutterMode, !mode.isEmpty {
                Text(mode)
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.accent)
                    .padding(.horizontal, WorkbenchSpacing.small)
                    .padding(.vertical, 2)
                    .background(WorkbenchColor.accentSoft, in: Capsule())
            }

            if entry.flutterMode == nil || entry.flutterMode?.isEmpty == true {
                Text("debug")
                    .workbenchFont(.caption)
                    .foregroundStyle(WorkbenchColor.textSecondary.opacity(0.7))
                    .padding(.horizontal, WorkbenchSpacing.small)
                    .padding(.vertical, 2)
                    .background(WorkbenchColor.divider.opacity(0.5), in: Capsule())
            }

            Spacer(minLength: WorkbenchSpacing.xs)

            HStack(spacing: WorkbenchSpacing.xs) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(WorkbenchColor.textSecondary)
                .opacity(isHovered ? 1 : 0)
                .accessibilityHidden(!isHovered)
                .accessibilityLabel("Edit \(entry.name)")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(WorkbenchColor.error)
                .opacity(isHovered ? 1 : 0)
                .accessibilityHidden(!isHovered)
                .accessibilityLabel("Delete \(entry.name)")
            }
        }
        .padding(.vertical, WorkbenchSpacing.xs)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var subdetail: String? {
        var parts: [String] = []
        if let program = entry.program, !program.isEmpty {
            parts.append(program)
        }
        if !entry.args.isEmpty {
            parts.append("args: \(entry.args.joined(separator: ", "))")
        }
        if !entry.toolArgs.isEmpty {
            parts.append("--\(entry.toolArgs.joined(separator: " --"))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  •  ")
    }
}

private struct LaunchConfigFormView: View {
    @State var entry: EditableLaunchConfig
    @State private var flutterMode: String = ""
    @State private var newArg = ""
    @State private var newToolArg = ""

    let isNew: Bool
    let onSave: (EditableLaunchConfig) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let flutterModes = [
        ("None", ""),
        ("debug", "debug"),
        ("profile", "profile"),
        ("release", "release"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "Add Configuration" : "Edit Configuration")
                    .workbenchFont(.heading)
                Spacer()
            }
            .padding(.horizontal, WorkbenchSpacing.medium)
            .padding(.vertical, WorkbenchSpacing.medium)

            Divider().overlay(WorkbenchColor.divider)

            ScrollView {
                Form {
                    Section {
                        TextField("Name", text: $entry.name, prompt: Text("e.g., Launch production app"))
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("Name")
                    }

                    Section {
                        Picker("Mode", selection: $flutterMode) {
                            ForEach(flutterModes, id: \.1) { label, value in
                                Text(label).tag(value)
                            }
                        }
                        .onChange(of: flutterMode) { _, newValue in
                            entry.flutterMode = newValue.isEmpty ? nil : newValue
                        }
                        .onAppear {
                            flutterMode = entry.flutterMode ?? ""
                        }

                        TextField("Program", text: Binding(
                            get: { entry.program ?? "" },
                            set: { entry.program = $0.isEmpty ? nil : $0 }
                        ), prompt: Text("lib/main.dart"))
                        .textFieldStyle(.roundedBorder)
                    }

                    Section("Arguments") {
                        stringListView(
                            title: "Args",
                            items: $entry.args,
                            newItem: $newArg,
                            placeholder: "e.g., --verbose"
                        )
                    }

                    Section("Tool Arguments") {
                        stringListView(
                            title: "Tool Args",
                            items: $entry.toolArgs,
                            newItem: $newToolArg,
                            placeholder: "e.g., --web-port=8080"
                        )
                    }

                    Section {
                        TextField("Device ID", text: Binding(
                            get: { entry.deviceId ?? "" },
                            set: { entry.deviceId = $0.isEmpty ? nil : $0 }
                        ), prompt: Text("Leave empty to use selected device"))
                        .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("Device Override")
                    } footer: {
                        Text("Specify a device ID to always run this configuration on a specific device.")
                    }
                }
                .formStyle(.grouped)
            }

            Divider().overlay(WorkbenchColor.divider)

            HStack(spacing: WorkbenchSpacing.small) {
                Spacer()

                Button("Cancel", role: .cancel) {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave(entry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(entry.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, WorkbenchSpacing.medium)
            .padding(.vertical, WorkbenchSpacing.small)
        }
        .background(WorkbenchColor.background)
    }

    private func stringListView(
        title: String,
        items: Binding<[String]>,
        newItem: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.small) {
            ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { index, item in
                HStack(spacing: WorkbenchSpacing.small) {
                    TextField("", text: Binding(
                        get: { item },
                        set: { newValue in
                            items.wrappedValue[index] = newValue
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button {
                        items.wrappedValue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(WorkbenchColor.error)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(title) \(item)")
                }
            }

            HStack(spacing: WorkbenchSpacing.small) {
                TextField("", text: newItem, prompt: Text(placeholder))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addItem(from: newItem, to: items)
                    }
                    .frame(minHeight: 44)

                Button {
                    addItem(from: newItem, to: items)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(WorkbenchColor.accent)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(newItem.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add \(title)")
            }
        }
    }

    private func addItem(from source: Binding<String>, to items: Binding<[String]>) {
        let trimmed = source.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.wrappedValue.append(trimmed)
        source.wrappedValue = ""
    }
}
