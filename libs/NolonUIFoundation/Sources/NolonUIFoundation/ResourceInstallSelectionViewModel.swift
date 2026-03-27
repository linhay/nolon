import Foundation
import Observation

@Observable
public final class ResourceInstallSelectionViewModel {
    public let itemName: String
    public let providers: [SkillInstallProviderOption]

    public var isProviderSheetPresented: Bool = false

    let targetProviderID: String?
    let onSelectProviderID: (String) -> Void

    public init(
        itemName: String,
        targetProviderID: String?,
        providers: [SkillInstallProviderOption],
        onSelectProviderID: @escaping (String) -> Void
    ) {
        self.itemName = itemName
        self.targetProviderID = targetProviderID
        self.providers = providers
        self.onSelectProviderID = onSelectProviderID
    }

    public func requestInstall() {
        if let targetProviderID {
            onSelectProviderID(targetProviderID)
        } else {
            isProviderSheetPresented = true
        }
    }

    public func handleSelectedProvider(_ providerID: String) {
        onSelectProviderID(providerID)
    }
}
