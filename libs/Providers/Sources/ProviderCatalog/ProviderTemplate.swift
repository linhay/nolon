import Foundation
import STFilePath

/// Built-in provider templates for quick setup.
/// These are templates used when adding a new provider, not actual providers.
public enum ProviderTemplate: String, CaseIterable, Sendable, Identifiable {
    case codex
    case codexXcode
    case claudeCode
    case opencode
    case copilot
    case gemini
    case antigravity
    case pi

    public var id: String { rawValue }

    /// Stable provider UUID used for built-in original vendor rows in `providers.json`.
    public var stableProviderUUID: String {
        switch self {
        case .codex:
            return "8A458B6A-C630-4B7F-AF77-9D88B36EA1A1"
        case .codexXcode:
            return "34D152D6-E3D2-486F-AE31-9AB8E0A1B402"
        case .claudeCode:
            return "2F8F2B72-3E6C-4A95-A71E-0D8C0A26E003"
        case .opencode:
            return "AB0CA372-7C3B-4A87-8A3E-D46FE9AE7604"
        case .copilot:
            return "0391A4B5-6F2F-4C3E-93FC-A6B9C4B2F705"
        case .gemini:
            return "5D1D9CFA-5F42-4A5E-9F15-4D4DCC0BC906"
        case .antigravity:
            return "D68D182E-4D57-4A6D-ACB8-2E8E53B9BA07"
        case .pi:
            return "E3C2755A-9B4F-4145-AB1C-FB6D4AA6AD08"
        }
    }

    /// Configuration loaded from JSON.
    public var config: ProviderTemplateConfig? {
        ProviderTemplateLoader.shared.config(for: rawValue)
    }

    /// Human-readable display name.
    public var displayName: String {
        config?.displayName ?? rawValue.capitalized
    }

    /// CLI executable name for provider discovery (e.g. "codex", "claude").
    public var cliName: String {
        config?.cliName ?? rawValue
    }

    /// Stable provider id used by CLI output.
    public var providerID: String {
        switch self {
        case .claudeCode:
            return "claude"
        default:
            return rawValue
        }
    }

    /// Icon name for this template.
    public var iconName: String {
        config?.iconName ?? "questionmark.circle"
    }

    /// Logo file name in lobe-icons library (without extension).
    public var logoFile: String {
        config?.logoFile ?? rawValue
    }

    public var vendorCategory: VendorCategory? {
        guard let raw = config?.vendorCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }
        return VendorCategory(rawValue: raw)
    }

    public var supportsNativeMcpConfig: Bool {
        config?.supportsNativeMcpConfig ?? true
    }

    public var supportsAccounts: Bool {
        config?.supportsAccounts ?? false
    }

    public var supportsMultiAccount: Bool {
        config?.supportsMultiAccount ?? false
    }

    public var secondaryResourceKind: SecondaryResourceKind {
        SecondaryResourceKind(rawTemplateValue: config?.secondaryResourceLabel) ?? .workflows
    }

    public var secondaryResourceLabelLocalizationKey: String {
        secondaryResourceKind.localizationKey
    }

    public var secondaryResourceLabelFallback: String {
        secondaryResourceKind.fallbackLabel
    }

    /// Default path for this template.
    public var defaultSkillsPath: URL {
        resolvePath(base: vendorBaseURL, relativePath: relativeSkillsPath)
    }

    /// Default workflow path for this template.
    public var defaultWorkflowPath: URL {
        resolvePath(base: vendorBaseURL, relativePath: relativeWorkflowPath)
    }

    /// Default command path for this template (OpenCode).
    public var defaultCommandPath: URL? {
        guard let relativePath = config?.defaultCommandPath else { return nil }
        return resolvePath(base: vendorBaseURL, relativePath: relativePath)
    }

    public var usesCommandFiles: Bool {
        defaultCommandPath != nil || rawValue == "opencode"
    }

    /// Documentation URL for this template.
    public var documentationURL: URL? {
        guard let urlString = config?.documentationURL else { return nil }
        return URL(string: urlString)
    }

    /// MCP documentation URL for this template.
    public var mcpDocumentationURL: URL? {
        guard let urlString = config?.mcpDocumentationURL else { return nil }
        return URL(string: urlString)
    }

    /// Default MCP configuration path for this template.
    public var defaultMcpConfigPath: URL {
        resolvePath(base: vendorBaseURL, relativePath: relativeMcpConfigPath)
    }

    /// Additional default skills paths for this template (penetration reading).
    public var defaultSkillsPaths: [URL] {
        let homeURL = currentUserHomeURL()
        return (config?.defaultSkillsPaths ?? []).map { path in
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(".") {
                return resolvePath(base: homeURL, relativePath: trimmed)
            }
            return resolvePath(base: vendorBaseURL, relativePath: trimmed)
        }
    }

    // MARK: - Project-scoped paths

    public var relativeSkillsPath: String { config?.defaultSkillsPath ?? ".\(rawValue)/skills" }
    public var relativeWorkflowPath: String { config?.defaultWorkflowPath ?? ".\(rawValue)/workflows" }
    public var relativeMcpConfigPath: String { config?.defaultMcpConfigPath ?? ".\(rawValue)/mcp_settings.json" }

    public func skillsPath(forProjectRoot projectRoot: URL) -> URL {
        resolvePath(base: projectBaseURL(projectRoot: projectRoot), relativePath: relativeSkillsPath)
    }

    public func workflowPath(forProjectRoot projectRoot: URL) -> URL {
        resolvePath(base: projectBaseURL(projectRoot: projectRoot), relativePath: relativeWorkflowPath)
    }

    public func commandPath(forProjectRoot projectRoot: URL) -> URL? {
        guard let relativePath = config?.defaultCommandPath else { return nil }
        return resolvePath(base: projectBaseURL(projectRoot: projectRoot), relativePath: relativePath)
    }

    public func mcpConfigPath(forProjectRoot projectRoot: URL) -> URL {
        resolvePath(base: projectBaseURL(projectRoot: projectRoot), relativePath: relativeMcpConfigPath)
    }

    /// Create a `Provider` instance from this template.
    public func createProvider() -> Provider {
        let commandPath = defaultCommandPath?.path
        let effectiveWorkflowPath = commandPath ?? defaultWorkflowPath.path
        return Provider(
            id: stableProviderUUID,
            kind: .vendor,
            name: displayName,
            defaultSkillsPath: defaultSkillsPath.path,
            workflowPath: effectiveWorkflowPath,
            commandPath: commandPath,
            iconName: iconName,
            installMethod: .symlink,
            vendorCategory: vendorCategory,
            templateId: rawValue,
            additionalSkillsPaths: defaultSkillsPaths.map { $0.path },
            documentationURL: documentationURL
        )
    }

    // MARK: - Helpers

    private var vendorBaseURL: URL {
        vendorBaseURL(userHome: currentUserHomeURL())
    }

    private func projectBaseURL(projectRoot: URL) -> URL {
        if let relative = config?.projectHomeRelativePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !relative.isEmpty
        {
            return resolvePath(base: projectRoot, relativePath: relative)
        }
        return vendorBaseURL(userHome: projectRoot)
    }

    private func vendorBaseURL(userHome: URL) -> URL {
        // Use a vendor home folder under the provided base when configured (e.g. "~/.codex" or "<project>/.codex").
        if let relative = config?.vendorHomeRelativePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !relative.isEmpty
        {
            return resolvePath(base: userHome, relativePath: relative)
        }

        // Default: use the provided base.
        return userHome
    }

    private func resolvePath(base: URL, relativePath: String) -> URL {
        let trimmed = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return base }

        var url = base
        for component in trimmed.split(separator: "/").map(String.init) {
            url.appendPathComponent(component)
        }
        return url
    }

    private func currentUserHomeURL() -> URL {
        if let home = ProcessInfo.processInfo.environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !home.isEmpty {
            return STFolder(home).url
        }
        return STFolder(NSHomeDirectory()).url
    }

    /// Resolves a user-facing provider identifier to a template.
    /// Accepts both `rawValue` and stable `providerID`, and keeps aliases for compatibility.
    public static func resolve(providerID: String) -> ProviderTemplate? {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "codex-xcode" || normalized == "codexxcode" {
            return .codexXcode
        }
        return allCases.first { template in
            normalized == template.rawValue.lowercased() || normalized == template.providerID.lowercased()
        }
    }
}

public enum SecondaryResourceKind: String, Sendable {
    case workflows
    case prompts
    case commands

    init?(rawTemplateValue: String?) {
        guard let rawTemplateValue else { return nil }
        let normalized = rawTemplateValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "", "workflow", "workflows":
            self = .workflows
        case "prompt", "prompts":
            self = .prompts
        case "command", "commands":
            self = .commands
        default:
            return nil
        }
    }

    var localizationKey: String {
        switch self {
        case .workflows:
            return "provider.secondary_resource.workflows"
        case .prompts:
            return "provider.secondary_resource.prompts"
        case .commands:
            return "provider.secondary_resource.commands"
        }
    }

    var fallbackLabel: String {
        switch self {
        case .workflows:
            return "Workflow Folder"
        case .prompts:
            return "Prompt Folder"
        case .commands:
            return "Command Folder"
        }
    }
}
