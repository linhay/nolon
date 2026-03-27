import Foundation

public struct CodexAdvancedMetaRowData: Identifiable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let isMonospaced: Bool

    public init(id: String, text: String, isMonospaced: Bool = false) {
        self.id = id
        self.text = text
        self.isMonospaced = isMonospaced
    }
}
