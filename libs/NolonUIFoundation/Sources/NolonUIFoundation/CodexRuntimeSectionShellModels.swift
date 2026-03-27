import Foundation

public struct CodexRuntimeActionsBarData: Equatable, Sendable {
    public let refreshTitle: String
    public let refreshSystemImage: String
    public let stopSummary: String?
    public let isBusy: Bool

    public init(
        refreshTitle: String = NSLocalizedString(
            "codex.runtime.action.refresh",
            value: "Refresh",
            comment: "Refresh runtime action"
        ),
        refreshSystemImage: String = "arrow.clockwise",
        stopSummary: String?,
        isBusy: Bool
    ) {
        self.refreshTitle = refreshTitle
        self.refreshSystemImage = refreshSystemImage
        self.stopSummary = stopSummary
        self.isBusy = isBusy
    }
}

public struct CodexRuntimeProcessesSectionData: Equatable, Sendable {
    public let title: String
    public let emptyText: String

    public init(
        title: String = NSLocalizedString(
            "codex.runtime.processes.title",
            value: "Runtime Processes",
            comment: "Runtime process list title"
        ),
        emptyText: String = NSLocalizedString(
            "codex.runtime.processes.empty",
            value: "No running Codex processes.",
            comment: "No runtime process"
        )
    ) {
        self.title = title
        self.emptyText = emptyText
    }
}
