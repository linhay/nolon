import Foundation

public struct QuickSwitchProviderOptionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isSelected: Bool

    public init(
        id: String,
        name: String,
        isSelected: Bool
    ) {
        self.id = id
        self.name = name
        self.isSelected = isSelected
    }
}

public struct QuickSwitchHeaderData: Equatable, Sendable {
    public let title: String
    public let providerDisplayName: String
    public let providers: [QuickSwitchProviderOptionData]
    public let isLoading: Bool

    public init(
        title: String = NSLocalizedString(
            "quickswitch.header.title",
            value: "快速切换账号",
            comment: "Quick switch header title"
        ),
        providerDisplayName: String,
        providers: [QuickSwitchProviderOptionData],
        isLoading: Bool
    ) {
        self.title = title
        self.providerDisplayName = providerDisplayName
        self.providers = providers
        self.isLoading = isLoading
    }
}
