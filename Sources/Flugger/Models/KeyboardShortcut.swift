import SwiftUI

enum WorkbenchAction: String, CaseIterable, Codable, Identifiable {
    case pubGet
    case cleanAndPubGet
    case run
    case stop
    case hotReload
    case hotRestart
    case focusConsoleSearch
    case copyVisibleOutput
    case exportVisibleOutput
    case clearConsole
    case toggleTerminal
    case increaseAppFontSize
    case decreaseAppFontSize

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pubGet: "Pub Get"
        case .cleanAndPubGet: "Clean + Pub Get"
        case .run: "Run"
        case .stop: "Stop"
        case .hotReload: "Hot Reload"
        case .hotRestart: "Hot Restart"
        case .focusConsoleSearch: "Focus Console Search"
        case .copyVisibleOutput: "Copy Visible Output"
        case .exportVisibleOutput: "Export Visible Output"
        case .clearConsole: "Clear Console"
        case .toggleTerminal: "Toggle Terminal"
        case .increaseAppFontSize: "Increase App Font Size"
        case .decreaseAppFontSize: "Decrease App Font Size"
        }
    }

    static let projectActions: [WorkbenchAction] = [.pubGet, .cleanAndPubGet]
    static let runActions: [WorkbenchAction] = [.run, .stop, .hotReload, .hotRestart]
    static let consoleActions: [WorkbenchAction] = [
        .focusConsoleSearch,
        .copyVisibleOutput,
        .exportVisibleOutput,
        .clearConsole,
    ]
    static let terminalActions: [WorkbenchAction] = [.toggleTerminal]
    static let appearanceActions: [WorkbenchAction] = [.increaseAppFontSize, .decreaseAppFontSize]
}

enum ShortcutModifier: String, CaseIterable, Codable, Identifiable {
    case control
    case option
    case shift
    case command

    var id: String { rawValue }

    var label: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        case .shift: "Shift"
        case .command: "Command"
        }
    }

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    var eventModifier: EventModifiers {
        switch self {
        case .control: .control
        case .option: .option
        case .shift: .shift
        case .command: .command
        }
    }

    static let displayOrder: [ShortcutModifier] = [.control, .option, .shift, .command]
}

enum ShortcutKey: String, CaseIterable, Codable, Identifiable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z
    case zero = "0"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case period = "."
    case comma = ","
    case slash = "/"
    case semicolon = ";"
    case openBracket = "["
    case closeBracket = "]"
    case minus = "-"
    case plus = "+"
    case graveAccent = "`"
    case returnKey = "return"
    case space = "space"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .returnKey: "Return"
        case .space: "Space"
        default: rawValue.uppercased()
        }
    }

    var shortcutSymbol: String {
        switch self {
        case .returnKey: "↩"
        case .space: "Space"
        default: displayName
        }
    }

    var keyEquivalent: KeyEquivalent {
        switch self {
        case .returnKey: .return
        case .space: .space
        default: KeyEquivalent(Character(rawValue))
        }
    }

    static let letters = allCases.filter { $0.rawValue.count == 1 && $0.rawValue.first?.isLetter == true }
    static let numbers = allCases.filter { $0.rawValue.count == 1 && $0.rawValue.first?.isNumber == true }
    static let symbols: [ShortcutKey] = [
        .period,
        .comma,
        .slash,
        .semicolon,
        .openBracket,
        .closeBracket,
        .minus,
        .plus,
        .graveAccent,
    ]
    static let special: [ShortcutKey] = [.returnKey, .space]
}

struct WorkbenchShortcut: Codable, Hashable {
    var key: ShortcutKey
    var modifiers: Set<ShortcutModifier>

    var eventModifiers: EventModifiers {
        modifiers.reduce(into: EventModifiers()) { result, modifier in
            result.insert(modifier.eventModifier)
        }
    }

    var displayName: String {
        let prefix = ShortcutModifier.displayOrder
            .filter(modifiers.contains)
            .map(\.symbol)
            .joined()
        return prefix + key.shortcutSymbol
    }

    var hasPrimaryModifier: Bool {
        modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control)
    }
}

extension WorkbenchAction {
    var defaultShortcut: WorkbenchShortcut {
        switch self {
        case .pubGet:
            WorkbenchShortcut(key: .g, modifiers: [.command, .option])
        case .cleanAndPubGet:
            WorkbenchShortcut(key: .g, modifiers: [.command, .option, .shift])
        case .run:
            WorkbenchShortcut(key: .returnKey, modifiers: [.command])
        case .stop:
            WorkbenchShortcut(key: .period, modifiers: [.command])
        case .hotReload:
            WorkbenchShortcut(key: .r, modifiers: [.command])
        case .hotRestart:
            WorkbenchShortcut(key: .r, modifiers: [.command, .shift])
        case .focusConsoleSearch:
            WorkbenchShortcut(key: .f, modifiers: [.command])
        case .copyVisibleOutput:
            WorkbenchShortcut(key: .c, modifiers: [.command, .option])
        case .exportVisibleOutput:
            WorkbenchShortcut(key: .e, modifiers: [.command, .shift])
        case .clearConsole:
            WorkbenchShortcut(key: .k, modifiers: [.command])
        case .toggleTerminal:
            WorkbenchShortcut(key: .graveAccent, modifiers: [.control])
        case .increaseAppFontSize:
            WorkbenchShortcut(key: .plus, modifiers: [.command])
        case .decreaseAppFontSize:
            WorkbenchShortcut(key: .minus, modifiers: [.command])
        }
    }
}
