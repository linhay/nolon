import Foundation

public enum CodexFeatureChipTone: Sendable {
    case success
    case info
    case warning
    case error
    case secondary
}

public struct CodexAdvancedFeatureRowData: Identifiable, Sendable {
    public let id: String
    public let keyText: String
    public let descriptionText: String
    public let maturityText: String
    public let sourceText: String
    public let queryText: String
    public let maturityTone: CodexFeatureChipTone
    public let sourceTone: CodexFeatureChipTone
    public let isEnabled: Bool

    public init(
        id: String,
        keyText: String,
        descriptionText: String,
        maturityText: String,
        sourceText: String,
        queryText: String,
        maturityTone: CodexFeatureChipTone,
        sourceTone: CodexFeatureChipTone,
        isEnabled: Bool
    ) {
        self.id = id
        self.keyText = keyText
        self.descriptionText = descriptionText
        self.maturityText = maturityText
        self.sourceText = sourceText
        self.queryText = queryText
        self.maturityTone = maturityTone
        self.sourceTone = sourceTone
        self.isEnabled = isEnabled
    }
}
