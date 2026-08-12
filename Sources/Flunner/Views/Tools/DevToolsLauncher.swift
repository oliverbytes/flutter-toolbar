import AppKit
import Foundation

enum DevToolsPage: String, CaseIterable {
    case inspector
    case performance
    case cpuProfiler
    case memory
    case network
    case appSize
    case deepLinks

    var label: String {
        switch self {
        case .inspector: "Inspector"
        case .performance: "Performance"
        case .cpuProfiler: "CPU Profiler"
        case .memory: "Memory"
        case .network: "Network"
        case .appSize: "App Size"
        case .deepLinks: "Deep Links"
        }
    }

    var systemImage: String {
        switch self {
        case .inspector: "rectangle.3.group"
        case .performance: "gauge.with.dots.needle.33percent"
        case .cpuProfiler: "cpu"
        case .memory: "memorychip"
        case .network: "network"
        case .appSize: "shippingbox"
        case .deepLinks: "link"
        }
    }

    var urlFragment: String {
        switch self {
        case .inspector: "inspector"
        case .performance: "performance"
        case .cpuProfiler: "cpu-profiler"
        case .memory: "memory"
        case .network: "network"
        case .appSize: "app-size"
        case .deepLinks: "deep-links"
        }
    }
}

enum DevToolsLauncher {
    static func open(vmServiceUri: String, onLog: ((String) -> Void)? = nil) {
        launchDevTools(arguments: ["--vm-uri=\(vmServiceUri)", "--launch-browser"], onLog: onLog)
    }

    static func open(page: DevToolsPage, vmServiceUri: String, onLog: ((String) -> Void)? = nil) {
        launchDevTools(
            arguments: ["--vm-uri=\(vmServiceUri)", "--launch-browser", "--devtools-server-mode"],
            onLog: onLog,
            onServerReady: { serverURL in
                let pageURL = "\(serverURL)/#/\(page.urlFragment)"
                NSWorkspace.shared.open(URL(string: pageURL)!)
            }
        )
    }

    private static func launchDevTools(
        arguments: [String],
        onLog: ((String) -> Void)?,
        onServerReady: ((String) -> Void)? = nil
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let args = arguments.joined(separator: " ")
        process.arguments = ["-ic", "dart devtools \(args)"]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stdoutPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let normalized = text.replacingOccurrences(of: "\r", with: "\n")
            for line in normalized.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                onLog?(trimmed)

                if let range = trimmed.range(of: "Serving DevTools at ") {
                    let rawURL = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if let callback = onServerReady {
                        callback(rawURL)
                    }
                }
            }
        }

        process.terminationHandler = { _ in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
        }

        do {
            try process.run()
        } catch {
            onLog?("Failed to launch DevTools: \(error.localizedDescription)")
        }
    }
}
