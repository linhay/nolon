import Foundation

public struct CodexAdvancedRoleRowData: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let modelText: String
    public let editTitle: String

    public init(
        id: String,
        title: String,
        modelText: String,
        editTitle: String
    ) {
        self.id = id
        self.title = title
        self.modelText = modelText
        self.editTitle = editTitle
    }
}
