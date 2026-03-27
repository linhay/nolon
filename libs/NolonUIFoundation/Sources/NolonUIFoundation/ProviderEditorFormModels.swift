import Foundation

public struct ProviderNameSectionData: Sendable {
    public let title: String
    public let placeholder: String

    public init(title: String, placeholder: String) {
        self.title = title
        self.placeholder = placeholder
    }
}

public struct ProviderLabeledValueData: Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}
