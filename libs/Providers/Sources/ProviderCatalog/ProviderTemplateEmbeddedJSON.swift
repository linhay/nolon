import Foundation

enum ProviderTemplateEmbeddedJSON {
    static let content = #"""
{
    "codex": {
        "displayName": "Codex",
        "cliName": "codex",
        "iconName": "terminal",
        "logoFile": "openai",
        "vendorCategory": "original",
        "vendorHomeRelativePath": ".codex",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "prompts",
        "documentationURL": "https://developers.openai.com/codex/",
        "mcpDocumentationURL": "https://developers.openai.com/codex/mcp/",
        "defaultMcpConfigPath": "config.toml",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": true,
        "supportsMultiAccount": true,
        "secondaryResourceLabel": "Prompts",
        "vendorTabs": [
            "usage",
            "runtime",
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
        "vendorCategory": "integrated",
        "vendorHomeRelativePath": "Library/Developer/Xcode/CodingAssistant/codex",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "prompts",
        "documentationURL": "https://developer.apple.com/documentation/Xcode/setting-up-coding-intelligence",
        "mcpDocumentationURL": "https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence",
        "defaultMcpConfigPath": "config.toml",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": false,
        "supportsMultiAccount": false,
        "secondaryResourceLabel": "Prompts",
        "vendorTabs": [
            "rules",
            "binary",
            "runtime",
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
        "vendorCategory": "original",
        "defaultSkillsPath": ".claude/skills",
        "defaultWorkflowPath": ".claude/workflows",
        "documentationURL": "https://code.claude.com/docs/en/overview",
        "mcpDocumentationURL": "https://docs.claude.ai/docs/en/mcp#option-1%3A-exclusive-control-with-managed-mcp-json",
        "defaultMcpConfigPath": ".claude.json",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": true,
        "supportsMultiAccount": true,
        "secondaryResourceLabel": "Workflows",
        "vendorTabs": [
            "usage",
            "rules"
        ]
    },
    "opencode": {
        "displayName": "OpenCode",
        "cliName": "opencode",
        "iconName": "chevron.left.forwardslash.chevron.right",
        "logoFile": "opencode",
        "vendorCategory": "integrated",
        "vendorHomeRelativePath": ".config/opencode",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "commands",
        "defaultCommandPath": "commands",
        "documentationURL": "https://opencode.ai/docs/skills",
        "mcpDocumentationURL": "https://opencode.ai/docs/mcp-servers/",
        "defaultMcpConfigPath": "opencode.json",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": false,
        "supportsMultiAccount": false,
        "secondaryResourceLabel": "Commands",
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
        "vendorCategory": "integrated",
        "vendorHomeRelativePath": ".copilot",
        "defaultSkillsPath": "agents",
        "defaultWorkflowPath": "workflows",
        "documentationURL": "https://docs.github.com/en/copilot/concepts/agents/about-agent-skills",
        "mcpDocumentationURL": "https://code.visualstudio.com/docs/copilot/customization/mcp-servers",
        "defaultMcpConfigPath": "mcp_settings.json",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": false,
        "supportsMultiAccount": false,
        "secondaryResourceLabel": "Workflows"
    },
    "gemini": {
        "displayName": "Gemini CLI",
        "cliName": "gemini",
        "iconName": "sparkles",
        "logoFile": "gemini",
        "vendorCategory": "original",
        "vendorHomeRelativePath": ".gemini",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "workflows",
        "documentationURL": "https://geminicli.com/docs/cli/skills/",
        "mcpDocumentationURL": "https://geminicli.com/docs/tools/mcp-server/",
        "defaultMcpConfigPath": "settings.json",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": true,
        "supportsMultiAccount": false,
        "secondaryResourceLabel": "Workflows",
        "vendorTabs": [
            "usage"
        ]
    },
    "antigravity": {
        "displayName": "Antigravity",
        "cliName": "antigravity",
        "iconName": "arrow.up.circle",
        "logoFile": "antigravity",
        "vendorCategory": "integrated",
        "vendorHomeRelativePath": ".gemini/antigravity",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "global_workflows",
        "documentationURL": "https://antigravity.google/docs/skills",
        "mcpDocumentationURL": "https://antigravity.google/docs/mcp",
        "defaultMcpConfigPath": "mcp_config.json",
        "supportsNativeMcpConfig": true,
        "supportsAccounts": true,
        "supportsMultiAccount": false,
        "secondaryResourceLabel": "Workflows",
        "vendorTabs": [
            "usage"
        ],
        "defaultSkillsPaths": [
            "skills",
            ".gemini/skills"
        ]
    },
    "pi": {
        "displayName": "Pi",
        "cliName": "pi",
        "iconName": "point.3.connected.trianglepath.dotted",
        "logoFile": "pi",
        "vendorCategory": "integrated",
        "vendorHomeRelativePath": ".pi/agent",
        "projectHomeRelativePath": ".pi",
        "defaultSkillsPath": "skills",
        "defaultWorkflowPath": "prompts",
        "documentationURL": "https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent",
        "defaultMcpConfigPath": "unsupported",
        "supportsNativeMcpConfig": false,
        "supportsAccounts": true,
        "supportsMultiAccount": false,
        "secondaryResourceLabel": "Prompts"
    }
}
"""#
}
