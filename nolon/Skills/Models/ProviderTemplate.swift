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
    
    /// Create a Provider instance from this template
    public func createProvider() -> Provider {
        Provider(
            name: displayName,
            path: defaultPath.path,
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
