import Combine
import Foundation

@MainActor
final class KeyboardShortcutStore: ObservableObject {
    @Published private(set) var bindings: [WorkbenchAction: WorkbenchShortcut]
    @Published private(set) var validationMessage: String?

    private let defaults: UserDefaults
    private let storageKey = "keyboardShortcuts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var loaded = Self.defaultBindings
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([String: WorkbenchShortcut].self, from: data)
        {
            for (rawAction, shortcut) in stored {
                guard let action = WorkbenchAction(rawValue: rawAction), shortcut.hasPrimaryModifier else { continue }
                loaded[action] = shortcut
            }
        }
        bindings = Self.removingDuplicateBindings(from: loaded)
    }

    func binding(for action: WorkbenchAction) -> WorkbenchShortcut {
        bindings[action] ?? action.defaultShortcut
    }

    func setKey(_ key: ShortcutKey, for action: WorkbenchAction) {
        var shortcut = binding(for: action)
        shortcut.key = key
        apply(shortcut, to: action)
    }

    func toggleModifier(_ modifier: ShortcutModifier, for action: WorkbenchAction) {
        var shortcut = binding(for: action)
        if shortcut.modifiers.contains(modifier) {
            shortcut.modifiers.remove(modifier)
        } else {
            shortcut.modifiers.insert(modifier)
        }

        guard shortcut.hasPrimaryModifier else {
            validationMessage = "A shortcut must include Command, Option, or Control."
            return
        }
        apply(shortcut, to: action)
    }

    func reset(_ action: WorkbenchAction) {
        apply(action.defaultShortcut, to: action)
    }

    func resetAll() {
        bindings = Self.defaultBindings
        validationMessage = nil
        save()
    }

    private func apply(_ shortcut: WorkbenchShortcut, to action: WorkbenchAction) {
        if let conflict = bindings.first(where: { $0.key != action && $0.value == shortcut })?.key {
            validationMessage = "\(shortcut.displayName) is already assigned to \(conflict.label)."
            return
        }

        bindings[action] = shortcut
        validationMessage = nil
        save()
    }

    private func save() {
        let stored = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static var defaultBindings: [WorkbenchAction: WorkbenchShortcut] {
        Dictionary(uniqueKeysWithValues: WorkbenchAction.allCases.map { ($0, $0.defaultShortcut) })
    }

    private static func removingDuplicateBindings(
        from loaded: [WorkbenchAction: WorkbenchShortcut]
    ) -> [WorkbenchAction: WorkbenchShortcut] {
        var result: [WorkbenchAction: WorkbenchShortcut] = [:]
        var used: Set<WorkbenchShortcut> = []

        for action in WorkbenchAction.allCases {
            let candidate = loaded[action] ?? action.defaultShortcut
            let shortcut = used.contains(candidate) ? action.defaultShortcut : candidate
            result[action] = shortcut
            used.insert(shortcut)
        }
        return result
    }
}
