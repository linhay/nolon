import Foundation

enum ProviderTemplateEmbeddedJSON {
    static let content = #"""
{
    "codex": {
        "displayName": "Codex",
        "cliName": "codex",
        "iconName": "terminal",
        "logoFile": "openai",
        "vendorHomeRelativePath": ".codex",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "prompts",
        "documentationURL": "https://developers.openai.com/codex/",
        "mcpDocumentationURL": "https://developers.openai.com/codex/mcp/",
        "defaultMcpConfigPath": "config.toml",
        "vendorTabs": [
            "usage",
            "rules",
            "binary",
            "agents"
        ],
        "defaultSkillsPaths": [
            "skills"
        ]
    },
    "codexXcode": {
        "displayName": "Codex (Xcode)",
        "cliName": "codex",
        "iconName": "hammer",
        "logoFile": "openai",
        "vendorHomeRelativePath": "Library/Developer/Xcode/CodingAssistant/codex",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "prompts",
        "documentationURL": "https://developer.apple.com/documentation/Xcode/setting-up-coding-intelligence",
        "mcpDocumentationURL": "https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence",
        "defaultMcpConfigPath": "config.toml",
        "vendorTabs": [
            "rules",
            "binary",
            "agents"
        ],
        "defaultSkillsPaths": [
            "skills"
        ]
    },
    "claude": {
        "displayName": "Claude Code",
        "cliName": "claude",
        "iconName": "bubble.left.and.bubble.right",
        "logoFile": "claude",
        "defaultSkillsPath": ".claude/skills",
        "defaultWorkflowPath": ".claude/workflows",
        "documentationURL": "https://code.claude.com/docs/en/overview",
        "mcpDocumentationURL": "https://docs.claude.ai/docs/en/mcp#option-1%3A-exclusive-control-with-managed-mcp-json",
        "defaultMcpConfigPath": ".claude.json"
    },
    "opencode": {
        "displayName": "OpenCode",
        "cliName": "opencode",
        "iconName": "chevron.left.forwardslash.chevron.right",
        "logoFile": "opencode",
        "vendorHomeRelativePath": ".config/opencode",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "commands",
        "defaultCommandPath": "commands",
        "documentationURL": "https://opencode.ai/docs/skills",
        "mcpDocumentationURL": "https://opencode.ai/docs/mcp-servers/",
        "defaultMcpConfigPath": "opencode.json",
        "defaultSkillsPaths": [
            "skills",
            ".claude/skills"
        ]
    },
    "copilot": {
        "displayName": "GitHub Copilot",
        "cliName": "copilot",
        "iconName": "airplane",
        "logoFile": "copilot",
        "vendorHomeRelativePath": ".copilot",
        "defaultSkillsPath": "agents",
        "defaultWorkflowPath": "workflows",
        "documentationURL": "https://docs.github.com/en/copilot/concepts/agents/about-agent-skills",
        "mcpDocumentationURL": "https://code.visualstudio.com/docs/copilot/customization/mcp-servers",
        "defaultMcpConfigPath": "mcp_settings.json"
    },
    "gemini": {
        "displayName": "Gemini CLI",
        "cliName": "gemini",
        "iconName": "sparkles",
        "logoFile": "gemini",
        "vendorHomeRelativePath": ".gemini",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "workflows",
        "documentationURL": "https://geminicli.com/docs/cli/skills/",
        "mcpDocumentationURL": "https://geminicli.com/docs/tools/mcp-server/",
        "defaultMcpConfigPath": "settings.json"
    },
    "antigravity": {
        "displayName": "Antigravity",
        "cliName": "antigravity",
        "iconName": "arrow.up.circle",
        "logoFile": "antigravity",
        "vendorHomeRelativePath": ".gemini/antigravity",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "global_workflows",
        "documentationURL": "https://antigravity.google/docs/skills",
        "mcpDocumentationURL": "https://antigravity.google/docs/mcp",
        "defaultMcpConfigPath": "mcp_config.json",
        "defaultSkillsPaths": [
            "skills",
            ".gemini/skills"
        ]
    }
}
"""#
}
