import SwiftUI

struct SessionDetailView: View {
    let session: RunSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.large) {
                HStack(alignment: .top, spacing: WorkbenchSpacing.medium) {
                    Image(systemName: session.outcome.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(outcomeColor)

                    VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                        Text(session.projectName)
                            .font(WorkbenchFont.display)
                            .foregroundStyle(WorkbenchColor.textPrimary)
                        Text("Run \(session.outcome.label.lowercased()) \(session.endedAt.formatted(.relative(presentation: .named)))")
                            .font(WorkbenchFont.body)
                            .foregroundStyle(WorkbenchColor.textSecondary)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: WorkbenchSpacing.large, verticalSpacing: WorkbenchSpacing.compact) {
                    SessionMetadataRow(label: "Outcome", value: session.outcome.label)
                    SessionMetadataRow(label: "Started", value: session.startedAt.formatted(date: .abbreviated, time: .standard))
                    SessionMetadataRow(label: "Duration", value: session.duration.formattedDuration)
                    SessionMetadataRow(label: "Device", value: session.deviceName)
                    SessionMetadataRow(label: "Configuration", value: session.configurationName)
                    SessionMetadataRow(label: "Project", value: session.projectPath)
                }
                .padding(WorkbenchSpacing.medium)
                .background(WorkbenchColor.surface, in: RoundedRectangle(cornerRadius: WorkbenchRadius.medium))

                HStack(alignment: .top, spacing: WorkbenchSpacing.compact) {
                    Image(systemName: "lock.doc")
                        .foregroundStyle(WorkbenchColor.accent)
                    VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                        Text("Console output was not stored")
                            .font(WorkbenchFont.heading)
                        Text("Flugger keeps session metadata only. Console text remains in memory during the current app launch and is discarded when Flugger quits.")
                            .font(WorkbenchFont.body)
                            .foregroundStyle(WorkbenchColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(WorkbenchSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WorkbenchColor.accentSoft, in: RoundedRectangle(cornerRadius: WorkbenchRadius.medium))
            }
            .padding(WorkbenchSpacing.extraLarge)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchColor.background)
        .navigationTitle(session.projectName)
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

private struct SessionMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label.uppercased())
                .font(WorkbenchFont.caption.weight(.semibold))
                .foregroundStyle(WorkbenchColor.textSecondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(WorkbenchFont.body)
                .foregroundStyle(WorkbenchColor.textPrimary)
                .textSelection(.enabled)
        }
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1)))
    }
}
