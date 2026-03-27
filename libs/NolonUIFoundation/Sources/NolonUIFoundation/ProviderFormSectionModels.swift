import Foundation

public enum ProviderProjectFolderSectionMode: Sendable {
    case project
    case vendorLocked
}

public struct ProviderProjectFolderSectionData: Sendable {
    public let mode: ProviderProjectFolderSectionMode
    public let sectionTitle: String
    public let displayPath: String
    public let emptyPlaceholder: String
    public let chooseButtonTitle: String
    public let vendorLockedDescription: String

    public init(
        mode: ProviderProjectFolderSectionMode,
        sectionTitle: String,
        displayPath: String,
        emptyPlaceholder: String,
        chooseButtonTitle: String,
        vendorLockedDescription: String
    ) {
        self.mode = mode
        self.sectionTitle = sectionTitle
        self.displayPath = displayPath
        self.emptyPlaceholder = emptyPlaceholder
        self.chooseButtonTitle = chooseButtonTitle
        self.vendorLockedDescription = vendorLockedDescription
    }
}

public struct ProviderResolvedPathItemData: Sendable, Identifiable {
    public let id: String
    public let label: String
    public let path: String
    public let emptyPlaceholder: String

    public init(
        id: String,
        label: String,
        path: String,
        emptyPlaceholder: String
    ) {
        self.id = id
        self.label = label
        self.path = path
        self.emptyPlaceholder = emptyPlaceholder
    }
}

