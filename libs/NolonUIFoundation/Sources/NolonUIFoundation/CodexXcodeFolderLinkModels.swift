import Foundation

public struct CodexXcodeFolderLinkCardData: Identifiable, Sendable {
    public let id: String
    public let folderTitle: String
    public let statusText: String
    public let isLinked: Bool
    public let sourcePathText: String
    public let targetPathText: String
    public let hasVisibleEntries: Bool
    public let conflictHintText: String
    public let showInFinderTitle: String
    public let isApplying: Bool

    public init(
        id: String,
        folderTitle: String,
        statusText: String,
        isLinked: Bool,
        sourcePathText: String,
        targetPathText: String,
        hasVisibleEntries: Bool,
        conflictHintText: String,
        showInFinderTitle: String,
        isApplying: Bool
    ) {
        self.id = id
        self.folderTitle = folderTitle
        self.statusText = statusText
        self.isLinked = isLinked
        self.sourcePathText = sourcePathText
        self.targetPathText = targetPathText
        self.hasVisibleEntries = hasVisibleEntries
        self.conflictHintText = conflictHintText
        self.showInFinderTitle = showInFinderTitle
        self.isApplying = isApplying
    }
}
