import Foundation

public enum SidebarSectionBuilder {
    public static func buildSections(providers: [SidebarProviderInput]) -> [SidebarSection] {
        let mappedItems = providers.map(mapProviderItem)

        let sections: [SidebarSection] = [
            SidebarSection(
                id: .originalVendors,
                titleKey: "sidebar.providers.original_vendors",
                fallbackTitle: "Original Vendors",
                items: mappedItems.filter { $0.kind == .vendor && $0.vendorCategory == .original }
            ),
            SidebarSection(
                id: .integratedVendors,
                titleKey: "sidebar.providers.integrated_vendors",
                fallbackTitle: "Integrated Vendors",
                items: mappedItems.filter { $0.kind == .vendor && $0.vendorCategory != .original }
            ),
            SidebarSection(
                id: .projects,
                titleKey: "sidebar.providers.projects",
                fallbackTitle: "Projects",
                items: mappedItems.filter { $0.kind == .project }
            )
        ]

        return sections.filter { !$0.items.isEmpty }
    }

    private static func mapProviderItem(_ provider: SidebarProviderInput) -> SidebarProviderItem {
        SidebarProviderItem(
            id: provider.id,
            kind: provider.kind,
            vendorCategory: provider.vendorCategory,
            title: provider.name,
            subtitle: provider.subtitle,
            iconName: provider.iconName,
            hasDocumentation: provider.hasDocumentation
        )
    }
}
