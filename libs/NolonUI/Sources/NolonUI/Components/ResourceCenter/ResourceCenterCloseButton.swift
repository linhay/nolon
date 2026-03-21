import SwiftUI

public enum ResourceCenterCloseButtonMetrics {
    public static let iconSystemName = "xmark"
    public static let iconFontSize: CGFloat = 13
    public static let buttonFrameSize: CGFloat = 32
}

public struct ResourceCenterCloseButton: View {
    private let help: String
    private let enableCancelShortcut: Bool
    private let action: () -> Void

    public init(
        help: String = "Close",
        enableCancelShortcut: Bool = true,
        action: @escaping () -> Void
    ) {
        self.help = help
        self.enableCancelShortcut = enableCancelShortcut
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: ResourceCenterCloseButtonMetrics.iconSystemName)
                .font(.system(size: ResourceCenterCloseButtonMetrics.iconFontSize, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(
                    width: ResourceCenterCloseButtonMetrics.buttonFrameSize,
                    height: ResourceCenterCloseButtonMetrics.buttonFrameSize
                )
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .modifier(ResourceCenterCloseButtonCancelShortcutModifier(isEnabled: enableCancelShortcut))
    }
}

private struct ResourceCenterCloseButtonCancelShortcutModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.keyboardShortcut(.cancelAction)
        } else {
            content
        }
    }
}

#Preview("Resource Center Close Button") {
    ResourceCenterCloseButton(help: "Close Resource Center") {}
}
