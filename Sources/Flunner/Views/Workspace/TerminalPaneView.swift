import AppKit
import SwiftUI

struct TerminalPaneView: View {
    @ObservedObject var manager: TerminalWorkspaceManager
    let projectPath: String

    @AppStorage(PreferenceKeys.consoleFontSize) private var fontSize = 12.0

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().overlay(WorkbenchColor.divider)

            if let session = manager.selectedSession(for: projectPath),
               let selectedTabID = manager.selectedTabID(for: projectPath) {
                TerminalHostView(
                    session: session,
                    fontSize: CGFloat(fontSize),
                    focusRevision: manager.focusRevision
                )
                .id(selectedTabID)
                .padding(WorkbenchSpacing.small)
            } else {
                ContentUnavailableView {
                    Label("No Terminal", systemImage: "terminal")
                } description: {
                    Text("Create a terminal tab to start a shell in this project.")
                } actions: {
                    Button("New Terminal") {
                        manager.addTab(to: projectPath)
                    }
                }
            }
        }
        .background(WorkbenchColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terminal pane")
    }

    private var tabBar: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WorkbenchSpacing.xs) {
                    ForEach(manager.tabs(for: projectPath)) { tab in
                        TerminalTabItem(
                            tab: tab,
                            isSelected: manager.selectedTabID(for: projectPath) == tab.id,
                            onSelect: { manager.selectTab(tab.id, in: projectPath) },
                            onClose: { manager.closeTab(tab.id, in: projectPath) }
                        )
                    }
                }
                .padding(.leading, WorkbenchSpacing.small)
            }

            Divider()
                .frame(height: 18)

            Button {
                manager.addTab(to: projectPath)
            } label: {
                Label("New Terminal", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(WorkbenchIconButtonStyle(color: WorkbenchColor.accent))
            .frame(width: 36, height: 36)
            .workbenchTooltip("New terminal", placement: .below)
            .accessibilityLabel("New Terminal")
            .padding(.trailing, WorkbenchSpacing.xs)
        }
        .frame(height: 38)
        .background(WorkbenchColor.surface)
    }
}

struct TerminalResizeDivider: View {
    let currentHeight: Double
    let onChange: (Double) -> Void
    let onEnd: () -> Void

    @State private var startingHeight: Double?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle()
                .fill(WorkbenchColor.divider)
                .frame(height: 1)
        }
        .frame(height: 8)
        .contentShape(Rectangle())
        .pointerStyle(.rowResize)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startingHeight == nil { startingHeight = currentHeight }
                    guard let startingHeight else { return }
                    onChange(startingHeight - Double(value.translation.height))
                }
                .onEnded { _ in
                    startingHeight = nil
                    onEnd()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Resize terminal pane")
        .accessibilityValue("\(Int(currentHeight)) points high")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(currentHeight + 24)
            case .decrement:
                onChange(max(TerminalWorkspaceSnapshot.minimumPaneHeight, currentHeight - 24))
            @unknown default:
                return
            }
            onEnd()
        }
    }
}

private struct TerminalTabItem: View {
    let tab: TerminalTabSnapshot
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            Button(action: onSelect) {
                HStack(spacing: WorkbenchSpacing.small) {
                    Image(systemName: "terminal")
                        .foregroundStyle(isSelected ? WorkbenchColor.accent : WorkbenchColor.textSecondary)
                    Text(tab.title)
                        .workbenchFont(.caption, weight: isSelected ? .semibold : .regular)
                        .foregroundStyle(WorkbenchColor.textPrimary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(WorkbenchColor.textSecondary)
            .workbenchTooltip("Close \(tab.title)", placement: .below)
            .accessibilityLabel("Close \(tab.title)")
        }
        .padding(.leading, WorkbenchSpacing.small)
        .padding(.trailing, WorkbenchSpacing.xs)
        .frame(maxWidth: 220, minHeight: 28)
        .background(
            isSelected ? WorkbenchColor.accentSoft : Color.clear,
            in: RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            if isSelected {
                Capsule()
                    .fill(WorkbenchColor.accent)
                    .frame(height: 2)
                    .padding(.horizontal, WorkbenchSpacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TerminalHostView: NSViewRepresentable {
    let session: any TerminalSession
    let fontSize: CGFloat
    let focusRevision: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TerminalHostingView {
        let host = TerminalHostingView()
        host.attach(session.view)
        applyAppearance()
        requestFocusIfNeeded(context: context)
        return host
    }

    func updateNSView(_ host: TerminalHostingView, context: Context) {
        host.attach(session.view)
        applyAppearance()
        requestFocusIfNeeded(context: context)
    }

    static func dismantleNSView(_ host: TerminalHostingView, coordinator: Coordinator) {
        host.detach()
    }

    private func applyAppearance() {
        session.applyAppearance(
            fontSize: fontSize,
            foreground: NSColor(named: NSColor.Name("WorkbenchTextPrimary")) ?? .textColor,
            background: NSColor(named: NSColor.Name("WorkbenchBackground")) ?? .textBackgroundColor,
            caret: NSColor(named: NSColor.Name("WorkbenchAccent")) ?? .controlAccentColor
        )
    }

    private func requestFocusIfNeeded(context: Context) {
        guard focusRevision > context.coordinator.lastFocusRevision else { return }
        context.coordinator.lastFocusRevision = focusRevision
        DispatchQueue.main.async {
            session.focus()
        }
    }

    final class Coordinator {
        var lastFocusRevision = 0
    }
}

private final class TerminalHostingView: NSView {
    private weak var hostedView: NSView?
    private var hostedConstraints: [NSLayoutConstraint] = []

    func attach(_ view: NSView) {
        guard hostedView !== view else { return }
        detach()

        hostedView = view
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        hostedConstraints = [
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(hostedConstraints)
    }

    func detach() {
        NSLayoutConstraint.deactivate(hostedConstraints)
        hostedConstraints.removeAll()
        hostedView?.removeFromSuperview()
        hostedView = nil
    }
}
