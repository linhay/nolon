import Foundation

/// Installation target for skills - Codex or Claude Code
public enum SkillProvider: String, CaseIterable, Sendable, Identifiable, Hashable, Codable {
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
}
