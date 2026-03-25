import SwiftUI

public typealias ResourceCenterCloseButtonMetrics = FloatingCloseButtonMetrics

public struct ResourceCenterCloseButton: View {
    @State private var viewModel = ResourceCenterCloseButtonViewModel()
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
        FloatingCloseButton(
            help: help,
            enableCancelShortcut: enableCancelShortcut,
            action: action
        )
    }
}

#Preview("Resource Center Close Button") {
    ResourceCenterCloseButton(help: "Close Resource Center") {}
}
