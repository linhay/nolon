import SwiftUI
import NolonUIFoundation

public struct CLITerminalMenuButton: View {
    let title: String
    let systemImage: String
    let options: [CLITerminalMenuOption]
    let onSelect: (CLITerminalMenuOption) -> Void

    public init(
        title: String = NSLocalizedString(
            "provider.cli.open",
            value: "Open CLI",
            comment: "Open CLI"
        ),
        systemImage: String = "terminal",
        options: [CLITerminalMenuOption],
        onSelect: @escaping (CLITerminalMenuOption) -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.title) {
                    onSelect(option)
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .disabled(options.isEmpty)
    }
}
