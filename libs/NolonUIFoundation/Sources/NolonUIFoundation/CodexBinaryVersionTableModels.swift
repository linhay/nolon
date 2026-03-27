import Foundation

public struct CodexBinaryVersionTableData: Equatable, Sendable {
    public let nameTitle: String
    public let versionTitle: String
    public let sourceTitle: String
    public let stateTitle: String
    public let actionsTitle: String
    public let rows: [CodexBinaryVersionRowData]

    public init(
        nameTitle: String = NSLocalizedString(
            "codex.binary.table.name",
            value: "Name",
            comment: "Version table name"
        ),
        versionTitle: String = NSLocalizedString(
            "codex.binary.table.version",
            value: "Version",
            comment: "Version table version"
        ),
        sourceTitle: String = NSLocalizedString(
            "codex.binary.table.source",
            value: "Source",
            comment: "Version table source"
        ),
        stateTitle: String = NSLocalizedString(
            "codex.binary.table.state",
            value: "State",
            comment: "Version table state"
        ),
        actionsTitle: String = NSLocalizedString(
            "codex.binary.table.actions",
            value: "Actions",
            comment: "Version table actions"
        ),
        rows: [CodexBinaryVersionRowData]
    ) {
        self.nameTitle = nameTitle
        self.versionTitle = versionTitle
        self.sourceTitle = sourceTitle
        self.stateTitle = stateTitle
        self.actionsTitle = actionsTitle
        self.rows = rows
    }
}

public enum CodexBinaryVersionRowKind: Equatable, Sendable {
    case remote
    case local
}

public enum CodexBinaryRowTone: Equatable, Sendable {
    case primary
    case secondary
    case success
    case warning
    case error
}

public struct CodexBinaryVersionRowData: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: CodexBinaryVersionRowKind
    public let nameText: String
    public let versionText: String
    public let sourceText: String
    public let stateText: String
    public let stateTone: CodexBinaryRowTone
    public let actionTitle: String?
    public let actionEnabled: Bool
    public let isActionInProgress: Bool
    public let progressFraction: Double?
    public let progressText: String?
    public let inProgressFallbackText: String?
    public let isSelectable: Bool

    public init(
        id: String,
        kind: CodexBinaryVersionRowKind,
        nameText: String,
        versionText: String,
        sourceText: String,
        stateText: String,
        stateTone: CodexBinaryRowTone,
        actionTitle: String?,
        actionEnabled: Bool,
        isActionInProgress: Bool,
        progressFraction: Double?,
        progressText: String?,
        inProgressFallbackText: String?,
        isSelectable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.nameText = nameText
        self.versionText = versionText
        self.sourceText = sourceText
        self.stateText = stateText
        self.stateTone = stateTone
        self.actionTitle = actionTitle
        self.actionEnabled = actionEnabled
        self.isActionInProgress = isActionInProgress
        self.progressFraction = progressFraction
        self.progressText = progressText
        self.inProgressFallbackText = inProgressFallbackText
        self.isSelectable = isSelectable
    }
}
