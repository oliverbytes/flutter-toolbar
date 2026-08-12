import Foundation

enum WidgetPreviewerLauncher {
    static func open(projectPath: String, onLog: ((String, LogEntryType) -> Void)? = nil) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ic", "flutter pub global run widget_previewer"]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let normalized = text.replacingOccurrences(of: "\r", with: "\n")
            for line in normalized.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                onLog?(trimmed, .info)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let normalized = text.replacingOccurrences(of: "\r", with: "\n")
            for line in normalized.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                onLog?(trimmed, .error)
            }
        }

        process.terminationHandler = { _ in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        do {
            try process.run()
            onLog?("widget_previewer started", .command)
        } catch {
            onLog?("Failed to launch Widget Previewer: \(error.localizedDescription)", .error)
            onLog?("Make sure widget_previewer is installed: flutter pub global activate widget_previewer", .info)
        }
    }
}
