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
        emptyPlaceholder: String = NSLocalizedString(
            "add_provider.no_project_folder",
            value: "No project folder selected",
            comment: "No project folder selected"
        ),
        chooseButtonTitle: String = NSLocalizedString(
            "add_provider.choose",
            value: "Choose...",
            comment: "Choose button title"
        ),
        vendorLockedDescription: String = NSLocalizedString(
            "add_provider.kind.vendor_paths_locked",
            value: "Vendor paths are predefined and cannot be changed.",
            comment: "Vendor paths locked description"
        )
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
        emptyPlaceholder: String = NSLocalizedString(
            "add_provider.no_folder",
            value: "No folder selected",
            comment: "No folder selected"
        )
    ) {
        self.id = id
        self.label = label
        self.path = path
        self.emptyPlaceholder = emptyPlaceholder
    }
}
