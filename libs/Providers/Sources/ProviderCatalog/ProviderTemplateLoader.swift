import Foundation
import OSLog
import STFilePath

public final class ProviderTemplateLoader: @unchecked Sendable {
    public static let shared = ProviderTemplateLoader()

    private static let logger = Logger(subsystem: "Providers", category: "ProviderTemplateLoader")
    private static let nolonHomeVariable = "NOLON_HOME"
    private static let configRelativePath = "ProviderTemplate.json"

    private let lock = NSLock()
    private var configs: [String: ProviderTemplateConfig] = [:]
    private var isLoaded = false
    private let environment: [String: String]
    private let userHomeURL: URL
    private let fileManager: FileManager

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userHomeURL: URL = STFolder(NSHomeDirectory()).url,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.userHomeURL = userHomeURL
        self.fileManager = fileManager
    }

    public func load() {
        self.lock.lock()
        let alreadyLoaded = self.isLoaded
        self.lock.unlock()
        guard !alreadyLoaded else { return }

        do {
            let file = try self.bootstrapTemplateFileIfNeeded()
            let data = try file.data()
            let decoded = try JSONDecoder().decode([String: ProviderTemplateConfig].self, from: data)
            self.lock.lock()
            self.configs = decoded
            self.isLoaded = true
            let count = decoded.count
            self.lock.unlock()
            Self.logger.debug("Loaded \(count, privacy: .public) provider configurations from \(file.url.path, privacy: .public)")
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

    private func bootstrapTemplateFileIfNeeded() throws -> STFile {
        let targetFile = self.templateConfigFile()
        let parent = targetFile.parentFolder()
        _ = parent?.createIfNotExists()

        let expectedData = Data(ProviderTemplateEmbeddedJSON.content.utf8)
        let needsWrite: Bool
        if targetFile.isExists {
            let current = try? targetFile.data()
            needsWrite = current != expectedData
        } else {
            needsWrite = true
        }

        if needsWrite {
            try targetFile.overlay(with: expectedData)
        }
        return targetFile
    }

    private func templateConfigFile() -> STFile {
        let cliHome = resolveCLIHomeFolder()
        return cliHome.file(Self.configRelativePath)
    }

    private func resolveCLIHomeFolder() -> STFolder {
        let nolonHome: URL
        if let raw = environment[Self.nolonHomeVariable]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty
        {
            nolonHome = normalizeDirectoryPath(raw)
        } else {
            nolonHome = userHomeURL.appendingPathComponent(".nolon", isDirectory: true)
        }
        return STFolder(nolonHome.appendingPathComponent("cli", isDirectory: true))
    }

    private func normalizeDirectoryPath(_ rawPath: String) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return STFolder(expanded).url.standardizedFileURL
        }
        let currentDirectory = STFolder(self.fileManager.currentDirectoryPath)
        return currentDirectory.folder(expanded).url.standardizedFileURL
    }
}
