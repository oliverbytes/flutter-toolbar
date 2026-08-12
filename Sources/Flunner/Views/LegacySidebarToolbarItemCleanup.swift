import AppKit
import SwiftUI

enum WorkbenchTooltipPlacement {
    case above
    case below
}

struct WorkbenchTooltipAnchor: NSViewRepresentable {
    let text: String
    let placement: WorkbenchTooltipPlacement

    func makeNSView(context: Context) -> WorkbenchTooltipTrackingView {
        let view = WorkbenchTooltipTrackingView()
        view.update(text: text, placement: placement)
        return view
    }

    func updateNSView(_ nsView: WorkbenchTooltipTrackingView, context: Context) {
        nsView.update(text: text, placement: placement)
    }
}

@MainActor
final class WorkbenchTooltipTrackingView: NSView {
    private var tooltipText = ""
    private var placement = WorkbenchTooltipPlacement.above
    private var tooltipPanel: WorkbenchTooltipPanel?
    private var trackingAreaReference: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        showTooltip()
    }

    override func mouseExited(with event: NSEvent) {
        hideTooltip()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            hideTooltip()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    func update(text: String, placement: WorkbenchTooltipPlacement) {
        tooltipText = text
        self.placement = placement

        if tooltipPanel?.isVisible == true {
            showTooltip()
        }
    }

    private func showTooltip() {
        guard !tooltipText.isEmpty, let window else { return }

        let content = WorkbenchTooltipBubble(text: tooltipText)
        let hostingView = NSHostingView(rootView: content)
        let tooltipSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: tooltipSize)

        let panel = tooltipPanel ?? makeTooltipPanel()
        panel.contentView = hostingView
        panel.setContentSize(tooltipSize)

        let anchorInWindow = convert(bounds, to: nil)
        let anchorOnScreen = window.convertToScreen(anchorInWindow)
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? anchorOnScreen
        let gap = WorkbenchSpacing.small

        let aboveY = anchorOnScreen.maxY + gap
        let belowY = anchorOnScreen.minY - tooltipSize.height - gap
        let preferredY = placement == .above ? aboveY : belowY
        let alternateY = placement == .above ? belowY : aboveY

        let preferredFits = preferredY >= visibleFrame.minY
            && preferredY + tooltipSize.height <= visibleFrame.maxY
        let originY = preferredFits ? preferredY : alternateY
        let unclampedX = anchorOnScreen.midX - (tooltipSize.width / 2)
        let originX = min(
            max(unclampedX, visibleFrame.minX + gap),
            visibleFrame.maxX - tooltipSize.width - gap
        )

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        panel.orderFrontRegardless()
    }

    private func hideTooltip() {
        tooltipPanel?.orderOut(nil)
    }

    private func makeTooltipPanel() -> WorkbenchTooltipPanel {
        let panel = WorkbenchTooltipPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        tooltipPanel = panel
        return panel
    }
}

final class WorkbenchTooltipPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct WorkbenchTooltipBubble: View {
    let text: String
    @AppStorage(PreferenceKeys.appFontSize) private var appFontSize = AppFontSizing.defaultSize

    var body: some View {
        Text(text)
            .workbenchFont(.caption, weight: .medium)
            .foregroundStyle(WorkbenchColor.textPrimary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 280, alignment: .leading)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, WorkbenchSpacing.compact)
            .padding(.vertical, WorkbenchSpacing.small)
            .background(
                WorkbenchColor.surface,
                in: RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous)
                    .stroke(WorkbenchColor.divider, lineWidth: 1)
            }
            .accessibilityHidden(true)
            .workbenchAppFontSize(appFontSize)
    }
}
