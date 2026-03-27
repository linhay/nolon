import Foundation

public struct RepositoryEditorFooterData: Equatable, Sendable {
    public let errorMessage: String?
    public let cancelTitle: String
    public let primaryTitle: String
    public let isPrimaryDisabled: Bool

    public init(
        errorMessage: String?,
        cancelTitle: String = NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
        primaryTitle: String,
        isPrimaryDisabled: Bool
    ) {
        self.errorMessage = errorMessage
        self.cancelTitle = cancelTitle
        self.primaryTitle = primaryTitle
        self.isPrimaryDisabled = isPrimaryDisabled
    }
}
