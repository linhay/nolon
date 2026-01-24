import Foundation

/// Configuration data for a ProviderTemplate, loaded from JSON
public struct ProviderTemplateConfig: Codable, Sendable {
    public let displayName: String
    public let iconName: String
    public let logoFile: String
    public let defaultPath: String
    public let defaultWorkflowPath: String
    public let documentationURL: String?
    public let mcpDocumentationURL: String?
    public let defaultMcpConfigPath: String
    public let defaultSkillsPaths: [String]?
}

/// Singleton loader for ProviderTemplate configurations from JSON
@MainActor
public final class ProviderTemplateLoader {
    public static let shared = ProviderTemplateLoader()
    
    private var configs: [String: ProviderTemplateConfig] = [:]
    private var isLoaded = false
    
    private init() {}
    
    /// Load configurations from bundle JSON file
    public func load() {
        guard !isLoaded else { return }
        
        guard let url = Bundle.main.url(forResource: "ProviderTemplate", withExtension: "json") else {
            print("[ProviderTemplateLoader] ProviderTemplate.json not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            configs = try JSONDecoder().decode([String: ProviderTemplateConfig].self, from: data)
            isLoaded = true
            print("[ProviderTemplateLoader] Loaded \(configs.count) provider configurations")
        } catch {
            print("[ProviderTemplateLoader] Failed to load configurations: \(error)")
        }
    }
    
    /// Get configuration for a specific template
    public func config(for rawValue: String) -> ProviderTemplateConfig? {
        if !isLoaded { load() }
        return configs[rawValue]
    }
    
    /// Get all loaded configurations
    public var allConfigs: [String: ProviderTemplateConfig] {
        if !isLoaded { load() }
        return configs
    }
}
