import Foundation
import ProviderCatalog
import NolonUIFoundation

enum ProviderSidebarAdapter {
    static var accountsSelectionKey: String {
        SidebarSelectionKey.accounts.rawValue
    }

    static var pluginManagementSelectionKey: String {
        SidebarSelectionKey.pluginManagement.rawValue
    }

    static func providerSelectionKey(_ providerID: String) -> String {
        SidebarSelectionKey.provider(providerID).rawValue
    }

    static func sections(from providers: [Provider]) -> [SidebarSection] {
        SidebarSectionBuilder.buildSections(providers: providerInputs(from: providers))
    }

    private static func providerInputs(from providers: [Provider]) -> [SidebarProviderInput] {
        providers.map { provider in
            SidebarProviderInput(
                id: provider.id,
                kind: mapProviderKind(provider.kind),
                vendorCategory: mapVendorCategory(provider.vendorCategory),
                name: provider.displayName,
                subtitle: provider.defaultSkillsPath,
                iconName: provider.iconName,
                hasDocumentation: provider.documentationURL != nil
            )
        }
    }

    private static func mapProviderKind(_ kind: ProviderKind) -> SidebarProviderKind {
        switch kind {
        case .vendor:
            return .vendor
        case .project:
            return .project
        }
    }

    private static func mapVendorCategory(_ category: VendorCategory?) -> SidebarVendorCategory? {
        switch category {
        case .original:
            return .original
        case .integrated:
            return .integrated
        case nil:
            return nil
        }
    }
}
