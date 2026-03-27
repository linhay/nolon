import Foundation

public struct CodexRuntimeDiagnosticRowData: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct CodexRuntimeLogsSectionData: Equatable, Sendable {
    public let title: String
    public let pidText: String?
    public let refreshTitle: String
    public let copyTitle: String
    public let clearTitle: String
    public let isLoading: Bool
    public let logsText: String
    public let emptyText: String
    public let errorMessage: String?

    public init(
        title: String = NSLocalizedString(
            "codex.runtime.logs.title",
            value: "PID Logs",
            comment: "Runtime logs title"
        ),
        pidText: String?,
        refreshTitle: String = NSLocalizedString(
            "codex.runtime.logs.refresh",
            value: "Refresh Logs",
            comment: "Refresh logs action"
        ),
        copyTitle: String = NSLocalizedString(
            "generic.copy",
            value: "Copy",
            comment: "Copy"
        ),
        clearTitle: String = NSLocalizedString(
            "codex.runtime.logs.clear",
            value: "Clear",
            comment: "Clear logs action"
        ),
        isLoading: Bool,
        logsText: String,
        emptyText: String = NSLocalizedString(
            "codex.runtime.logs.empty",
            value: "No log output in selected window.",
            comment: "No logs"
        ),
        errorMessage: String?
    ) {
        self.title = title
        self.pidText = pidText
        self.refreshTitle = refreshTitle
        self.copyTitle = copyTitle
        self.clearTitle = clearTitle
        self.isLoading = isLoading
        self.logsText = logsText
        self.emptyText = emptyText
        self.errorMessage = errorMessage
    }
}
