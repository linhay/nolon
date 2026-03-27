import Foundation

public struct CodexRuntimeProcessRowData: Equatable, Sendable {
    public let id: String
    public let pidText: String
    public let elapsedText: String
    public let providerHint: String?
    public let commandText: String
    public let workingDirectory: String?
    public let stopTitle: String
    public let forceTitle: String
    public let isStopping: Bool
    public let isSelected: Bool

    public init(
        id: String,
        pidText: String,
        elapsedText: String,
        providerHint: String?,
        commandText: String,
        workingDirectory: String?,
        stopTitle: String = NSLocalizedString(
            "codex.runtime.process.stop",
            value: "Stop",
            comment: "Stop runtime process"
        ),
        forceTitle: String = NSLocalizedString(
            "codex.runtime.process.force",
            value: "Force",
            comment: "Force stop runtime process"
        ),
        isStopping: Bool,
        isSelected: Bool
    ) {
        self.id = id
        self.pidText = pidText
        self.elapsedText = elapsedText
        self.providerHint = providerHint
        self.commandText = commandText
        self.workingDirectory = workingDirectory
        self.stopTitle = stopTitle
        self.forceTitle = forceTitle
        self.isStopping = isStopping
        self.isSelected = isSelected
    }
}
