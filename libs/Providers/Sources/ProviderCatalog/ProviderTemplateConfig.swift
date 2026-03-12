import Foundation

/// Configuration data for a `ProviderTemplate`, loaded from JSON.
public struct ProviderTemplateConfig: Codable, Sendable {
    public let displayName: String
    public let cliName: String
    public let iconName: String
    public let logoFile: String
    public let vendorCategory: String?
    /// Optional vendor home relative path under user home (e.g. ".codex").
    public let vendorHomeRelativePath: String?
    /// Optional provider home relative path under project root.
    public let projectHomeRelativePath: String?
    public let defaultSkillsPath: String
    public let defaultWorkflowPath: String
    /// OpenCode uses command files instead of workflows.
    public let defaultCommandPath: String?
    public let documentationURL: String?
    public let mcpDocumentationURL: String?
    public let defaultMcpConfigPath: String
    public let defaultSkillsPaths: [String]?
    /// Extra tabs shown only for `.vendor` providers.
    public let vendorTabs: [String]?
    public let supportsNativeMcpConfig: Bool?
    public let supportsAccounts: Bool?
    public let supportsMultiAccount: Bool?
    public let secondaryResourceLabel: String?
}
