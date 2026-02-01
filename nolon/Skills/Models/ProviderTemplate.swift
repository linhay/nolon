import Foundation

/// Built-in provider templates for quick setup
/// These are templates used when adding a new provider, not actual providers
public enum ProviderTemplate: String, CaseIterable, Sendable, Identifiable {
    // Existing
    case codex
    case claudeCode
    case opencode
    case copilot
    case gemini
    case antigravity
    
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
    public var defaultSkillsPath: URL {
        resolvePath(base: vendorBaseURL, relativePath: relativeSkillsPath)
    }
    
    /// Default workflow path for this template
    @MainActor
    public var defaultWorkflowPath: URL {
        resolvePath(base: vendorBaseURL, relativePath: relativeWorkflowPath)
    }
    
    /// Default command path for this template (OpenCode).
    @MainActor
    public var defaultCommandPath: URL? {
        guard let relativePath = config?.defaultCommandPath else { return nil }
        return resolvePath(base: vendorBaseURL, relativePath: relativePath)
    }
    
    @MainActor
    public var usesCommandFiles: Bool {
        defaultCommandPath != nil || rawValue == "opencode"
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
        resolvePath(base: vendorBaseURL, relativePath: relativeMcpConfigPath)
    }
    
    /// Additional default skills paths for this template (penetration reading)
    @MainActor
    public var defaultSkillsPaths: [URL] {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
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
        resolvePath(base: vendorHomeURL(projectRoot: projectRoot), relativePath: relativeSkillsPath)
    }

    public func workflowPath(forProjectRoot projectRoot: URL) -> URL {
        resolvePath(base: vendorHomeURL(projectRoot: projectRoot), relativePath: relativeWorkflowPath)
    }

    public func commandPath(forProjectRoot projectRoot: URL) -> URL? {
        guard let relativePath = config?.defaultCommandPath else { return nil }
        return resolvePath(base: vendorHomeURL(projectRoot: projectRoot), relativePath: relativePath)
    }

    public func mcpConfigPath(forProjectRoot projectRoot: URL) -> URL {
        resolvePath(base: vendorHomeURL(projectRoot: projectRoot), relativePath: relativeMcpConfigPath)
    }

    /// Create a Provider instance from this template
    @MainActor
    public func createProvider() -> Provider {
        let commandPath = defaultCommandPath?.path
        let effectiveWorkflowPath = commandPath ?? defaultWorkflowPath.path
        return Provider(
            kind: .vendor,
            name: displayName,
            defaultSkillsPath: defaultSkillsPath.path,
            workflowPath: effectiveWorkflowPath,
            commandPath: commandPath,
            iconName: iconName,
            installMethod: .symlink,
            templateId: rawValue,
            additionalSkillsPaths: defaultSkillsPaths.map { $0.path },
            documentationURL: documentationURL
        )
    }

    // MARK: - Helpers

    @MainActor
    private var vendorBaseURL: URL {
        vendorHomeURL(projectRoot: URL(fileURLWithPath: NSHomeDirectory()))
    }

    @MainActor
    private func vendorHomeURL(projectRoot: URL) -> URL {
        // Use a vendor home folder under the provided base when configured (e.g. "~/.codex" or "<project>/.codex").
        if let relative = config?.vendorHomeRelativePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !relative.isEmpty
        {
            return resolvePath(base: projectRoot, relativePath: relative)
        }

        // Default: use the provided base.
        return projectRoot
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
}
