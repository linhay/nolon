import Foundation

/// Built-in provider templates for quick setup
/// These are templates used when adding a new provider, not actual providers
public enum ProviderTemplate: String, CaseIterable, Sendable, Identifiable {
    case codex
    case claude
    case opencode
    case copilot
    case gemini
    case antigravity

    public var id: String { rawValue }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .codex: return NSLocalizedString("provider.codex", comment: "Codex")
        case .claude: return NSLocalizedString("provider.claude", comment: "Claude Code")
        case .opencode: return NSLocalizedString("provider.opencode", comment: "OpenCode")
        case .copilot: return NSLocalizedString("provider.copilot", comment: "GitHub Copilot")
        case .gemini: return NSLocalizedString("provider.gemini", comment: "Gemini CLI")
        case .antigravity: return NSLocalizedString("provider.antigravity", comment: "Antigravity")
        }
    }
    
    /// Icon name for this template
    public var iconName: String {
        switch self {
        case .codex: return "terminal"
        case .claude: return "bubble.left.and.bubble.right"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .copilot: return "airplane"
        case .gemini: return "sparkles"
        case .antigravity: return "arrow.up.circle"
        }
    }
    
    /// Logo file name in lobe-icons library (without extension)
    public var logoFile: String {
        switch self {
        case .codex: return "openai"
        case .claude: return "claude"
        case .opencode: return "opencode"
        case .copilot: return "copilot"
        case .gemini: return "gemini"
        case .antigravity: return "antigravity"
        }
    }
    
    /// Default path for this template
    public var defaultPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex:
            return home.appendingPathComponent(".codex/skills/public")
        case .claude:
            return home.appendingPathComponent(".claude/skills")
        case .opencode:
            return home.appendingPathComponent(".config/opencode/skills")
        case .copilot:
            return home.appendingPathComponent(".copilot/skills")
        case .gemini:
            return home.appendingPathComponent(".gemini/skills")
        case .antigravity:
            return home.appendingPathComponent(".gemini/antigravity/skills")
        }
    }
    
    /// Default workflow path for this template
    public var defaultWorkflowPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex:
            return home.appendingPathComponent(".codex/workflows")
        case .claude:
            return home.appendingPathComponent(".claude/workflows")
        case .opencode:
            return home.appendingPathComponent(".config/opencode/workflows")
        case .copilot:
            return home.appendingPathComponent(".copilot/workflows")
        case .gemini:
            return home.appendingPathComponent(".gemini/workflows")
        case .antigravity:
            return home.appendingPathComponent(".gemini/antigravity/global_workflows")
        }
    }
    
    /// MCP documentation URL for this template
    public var mcpDocumentationURL: URL? {
        switch self {
        case .codex:
            return URL(string: "https://developers.openai.com/codex/mcp/")
        case .claude:
            return URL(string: "https://code.claude.com/docs/en/mcp#option-1%3A-exclusive-control-with-managed-mcp-json")
        case .opencode:
            return URL(string: "https://opencode.ai/docs/mcp-servers/")
        case .copilot:
            return URL(string: "https://code.visualstudio.com/docs/copilot/customization/mcp-servers")
        case .gemini:
            return URL(string: "https://geminicli.com/docs/tools/mcp-server/")
        case .antigravity:
            return URL(string: "https://antigravity.google/docs/mcp")
        }
    }
    
    /// Default MCP configuration path for this template
    public var defaultMcpConfigPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex:
            return home.appendingPathComponent(".codex/mcp_settings.json")
        case .claude:
            return home.appendingPathComponent(".claude.json")
        case .opencode:
            return home.appendingPathComponent(".config/opencode/mcp_settings.json")
        case .copilot:
            return home.appendingPathComponent(".copilot/mcp_settings.json")
        case .gemini:
            return home.appendingPathComponent(".gemini/mcp_settings.json")
        case .antigravity:
            return home.appendingPathComponent(".gemini/antigravity/mcp_settings.json")
        }
    }
    
    /// Create a Provider instance from this template
    public func createProvider() -> Provider {
        Provider(
            name: displayName,
            skillsPath: defaultPath.path,
            workflowPath: defaultWorkflowPath.path,
            iconName: iconName,
            installMethod: .symlink,
            templateId: rawValue
        )
    }
}

// MARK: - Legacy Compatibility

/// Legacy type alias for migration
@available(*, deprecated, renamed: "ProviderTemplate")
public typealias SkillProvider = ProviderTemplate
