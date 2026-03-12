import Foundation
import ProviderCatalog

public enum ProviderPresentationSections {
    public enum SectionID: String, Identifiable, Sendable {
        case originalVendors
        case integratedVendors
        case projects

        public var id: String { rawValue }
    }

    public struct ProviderSection: Identifiable, Sendable {
        public let id: SectionID
        public let titleKey: String
        public let fallbackTitle: String
        public let providers: [Provider]

        public init(id: SectionID, titleKey: String, fallbackTitle: String, providers: [Provider]) {
            self.id = id
            self.titleKey = titleKey
            self.fallbackTitle = fallbackTitle
            self.providers = providers
        }
    }

    public struct TemplateSection: Identifiable, Sendable {
        public let id: SectionID
        public let titleKey: String
        public let fallbackTitle: String
        public let templates: [ProviderTemplate]

        public init(id: SectionID, titleKey: String, fallbackTitle: String, templates: [ProviderTemplate]) {
            self.id = id
            self.titleKey = titleKey
            self.fallbackTitle = fallbackTitle
            self.templates = templates
        }
    }

    public static func providerSections(providers: [Provider]) -> [ProviderSection] {
        let sections: [ProviderSection] = [
            ProviderSection(
                id: .originalVendors,
                titleKey: "sidebar.providers.original_vendors",
                fallbackTitle: "Original Vendors",
                providers: providers.filter { $0.kind == .vendor && $0.vendorCategory == .original }
            ),
            ProviderSection(
                id: .integratedVendors,
                titleKey: "sidebar.providers.integrated_vendors",
                fallbackTitle: "Integrated Vendors",
                providers: providers.filter { $0.kind == .vendor && $0.vendorCategory != .original }
            ),
            ProviderSection(
                id: .projects,
                titleKey: "sidebar.providers.projects",
                fallbackTitle: "Projects",
                providers: providers.filter { $0.kind == .project }
            )
        ]

        return sections.filter { !$0.providers.isEmpty }
    }

    public static func templateSections(templates: [ProviderTemplate] = ProviderTemplate.allCases) -> [TemplateSection] {
        let vendorTemplates = templates.filter { $0.vendorCategory != nil }
        let sections: [TemplateSection] = [
            TemplateSection(
                id: .originalVendors,
                titleKey: "provider.vendor_category.original",
                fallbackTitle: "Original Vendors",
                templates: vendorTemplates.filter { $0.vendorCategory == .original }
            ),
            TemplateSection(
                id: .integratedVendors,
                titleKey: "provider.vendor_category.integrated",
                fallbackTitle: "Integrated Vendors",
                templates: vendorTemplates.filter { $0.vendorCategory == .integrated }
            )
        ]

        return sections.filter { !$0.templates.isEmpty }
    }

    public static func accountProviders(from providers: [Provider]) -> [ProviderSection] {
        let supported = providers.filter { provider in
            guard provider.kind == .vendor,
                  let templateId = provider.templateId,
                  let template = ProviderTemplate(rawValue: templateId)
            else {
                return false
            }
            return template.supportsAccounts && template != .pi
        }

        return providerSections(providers: supported).filter { !$0.providers.isEmpty && $0.id != .projects }
    }
}
