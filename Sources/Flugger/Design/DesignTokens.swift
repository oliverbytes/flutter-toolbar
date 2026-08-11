import SwiftUI

enum WorkbenchColor {
    static let accent = Color("WorkbenchAccent")
    static let accentSoft = Color("WorkbenchAccentSoft")
    static let background = Color("WorkbenchBackground")
    static let surface = Color("WorkbenchSurface")
    static let textPrimary = Color("WorkbenchTextPrimary")
    static let textSecondary = Color("WorkbenchTextSecondary")
    static let divider = Color("WorkbenchDivider")
    static let success = Color("WorkbenchSuccess")
    static let info = Color("WorkbenchInfo")
    static let warning = Color("WorkbenchWarning")
    static let error = Color("WorkbenchError")
}

enum WorkbenchSpacing {
    static let xs: CGFloat = 4
    static let small: CGFloat = 8
    static let compact: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
}

enum WorkbenchRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 14
}

enum WorkbenchFont {
    static let display = Font.system(size: 22, weight: .bold)
    static let heading = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 11)

    static func console(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

struct WorkbenchPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkbenchFont.body.weight(.semibold))
            .foregroundStyle(isEnabled ? WorkbenchColor.textPrimary : WorkbenchColor.textSecondary)
            .frame(minWidth: 88, minHeight: 44)
            .background(
                isEnabled ? WorkbenchColor.accent.opacity(configuration.isPressed ? 0.76 : 1) : WorkbenchColor.divider,
                in: RoundedRectangle(cornerRadius: WorkbenchRadius.medium, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: WorkbenchRadius.medium, style: .continuous))
    }
}

struct WorkbenchIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var color: Color = WorkbenchColor.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 44, height: 44)
            .foregroundStyle(isEnabled ? color : WorkbenchColor.textSecondary.opacity(0.42))
            .background(
                configuration.isPressed ? color.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: WorkbenchRadius.small, style: .continuous))
    }
}

private struct WorkbenchTooltipModifier: ViewModifier {
    let text: String
    let placement: WorkbenchTooltipPlacement

    func body(content: Content) -> some View {
        content
            .background {
                WorkbenchTooltipAnchor(text: text, placement: placement)
            }
            .accessibilityHint(text)
    }
}

extension View {
    func workbenchTooltip(
        _ text: String,
        placement: WorkbenchTooltipPlacement = .above
    ) -> some View {
        modifier(WorkbenchTooltipModifier(text: text, placement: placement))
    }
}
