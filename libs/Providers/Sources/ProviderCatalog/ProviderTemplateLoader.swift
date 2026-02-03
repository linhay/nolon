import Foundation
import OSLog

/// Singleton loader for `ProviderTemplate` configurations from JSON.
public final class ProviderTemplateLoader: @unchecked Sendable {
    public static let shared = ProviderTemplateLoader()

    private static let logger = Logger(subsystem: "Providers", category: "ProviderTemplateLoader")

    private let lock = NSLock()
    private var configs: [String: ProviderTemplateConfig] = [:]
    private var isLoaded = false

    private init() {}

    /// Load configurations from JSON file embedded in the `ProviderCatalog` SwiftPM bundle.
    public func load() {
        self.lock.lock()
        let alreadyLoaded = self.isLoaded
        self.lock.unlock()
        guard !alreadyLoaded else { return }

        guard let url = Bundle.module.url(forResource: "ProviderTemplate", withExtension: "json") else {
            Self.logger.error("ProviderTemplate.json not found in ProviderCatalog bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: ProviderTemplateConfig].self, from: data)
            self.lock.lock()
            self.configs = decoded
            self.isLoaded = true
            let count = decoded.count
            self.lock.unlock()
            Self.logger.debug("Loaded \(count, privacy: .public) provider configurations")
        } catch {
            Self.logger.error("Failed to load provider configurations: \(String(describing: error), privacy: .public)")
        }
    }

    /// Get configuration for a specific template.
    public func config(for rawValue: String) -> ProviderTemplateConfig? {
        self.loadIfNeeded()
        self.lock.lock()
        defer { self.lock.unlock() }
        if let config = self.configs[rawValue] { return config }

        // Backward compatibility: nolon historically used "claude" as the JSON key.
        if rawValue == "claudeCode" { return self.configs["claude"] }

        return nil
    }

    /// Get all loaded configurations.
    public var allConfigs: [String: ProviderTemplateConfig] {
        self.loadIfNeeded()
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.configs
    }

    private func loadIfNeeded() {
        self.lock.lock()
        let loaded = self.isLoaded
        self.lock.unlock()
        if !loaded { self.load() }
    }
}
