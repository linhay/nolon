import Foundation

public struct SettingsWorkspaceCardData: Sendable {
    public let label: String
    public let path: String

    public init(
        label: String = NSLocalizedString(
            "settings.workspace.current",
            value: "Current Workspace",
            comment: "Current workspace label"
        ),
        path: String
    ) {
        self.label = label
        self.path = path
    }
}
