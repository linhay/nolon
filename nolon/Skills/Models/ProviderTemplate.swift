import Foundation

/// Built-in provider templates for quick setup
/// These are templates used when adding a new provider, not actual providers
public enum ProviderTemplate: String, CaseIterable, Sendable, Identifiable {
    // Existing
    case codex
    case claude
    case opencode
    case copilot
    case gemini
    case antigravity
    
    // New
    case amp
    case clawdbot
    case cline
    case commandCode
    case cursor
    case droid
    case goose
    case kilo
    case kiro
    case mcpjam
    case openhands
    case pi
    case qoder
    case qwen
    case roo
    case trae
    case windsurf
    case zencoder
    case neovate

    public var id: String { rawValue }
    
    /// Configuration loaded from JSON
    @MainActor
    public var config: ProviderTemplateConfig? {
        ProviderTemplateLoader.shared.config(for: rawValue)
    }

    /// Human-readable display name
    @MainActor
    public var displayName: String {
        config?.displayName ?? rawValue.capitalized
    }
    
    /// Icon name for this template
    @MainActor
    public var iconName: String {
        config?.iconName ?? "questionmark.circle"
    }
    
    /// Logo file name in lobe-icons library (without extension)
    @MainActor
    public var logoFile: String {
        config?.logoFile ?? rawValue
    }
    
    /// Default path for this template
    @MainActor
    public var defaultPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let relativePath = config?.defaultPath ?? ".\(rawValue)/skills"
        return home.appendingPathComponent(relativePath)
    }
    
    /// Default workflow path for this template
    @MainActor
    public var defaultWorkflowPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let relativePath = config?.defaultWorkflowPath ?? ".\(rawValue)/workflows"
        return home.appendingPathComponent(relativePath)
    }
    
    /// Documentation URL for this template
    @MainActor
    public var documentationURL: URL? {
        guard let urlString = config?.documentationURL else { return nil }
        return URL(string: urlString)
    }
    
    /// MCP documentation URL for this template
    @MainActor
    public var mcpDocumentationURL: URL? {
        guard let urlString = config?.mcpDocumentationURL else { return nil }
        return URL(string: urlString)
    }
    
    /// Default MCP configuration path for this template
    @MainActor
    public var defaultMcpConfigPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let relativePath = config?.defaultMcpConfigPath ?? ".\(rawValue)/mcp_settings.json"
        return home.appendingPathComponent(relativePath)
    }
    
    /// Create a Provider instance from this template
    @MainActor
    public func createProvider() -> Provider {
        Provider(
            name: displayName,
            skillsPath: defaultPath.path,
            workflowPath: defaultWorkflowPath.path,
            iconName: iconName,
            installMethod: .symlink,
            templateId: rawValue,
            documentationURL: documentationURL
        )
    }
}

// MARK: - Legacy Compatibility

/// Legacy type alias for migration
@available(*, deprecated, renamed: "ProviderTemplate")
public typealias SkillProvider = ProviderTemplate
