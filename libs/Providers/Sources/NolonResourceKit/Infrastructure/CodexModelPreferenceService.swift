import Foundation
import TOML
import STFilePath
import CodexProvider

public struct CodexModelsCacheSnapshot: Sendable {
    public let models: [CodexModelsCache.Model]
    public let sourcePath: String?
    public let fetchedAt: Date?
    public let clientVersion: String?
    public let etag: String?

    public init(
        models: [CodexModelsCache.Model],
        sourcePath: String?,
        fetchedAt: Date?,
        clientVersion: String?,
        etag: String?
    ) {
        self.models = models
        self.sourcePath = sourcePath
        self.fetchedAt = fetchedAt
        self.clientVersion = clientVersion
        self.etag = etag
    }
}

public struct CodexModelPreferenceService: Sendable {
    private let homeDirectoryPath: @Sendable () -> String

    public init(homeDirectoryPath: @escaping @Sendable () -> String = { NSHomeDirectory() }) {
        self.homeDirectoryPath = homeDirectoryPath
    }

    public func supports(provider: Provider) -> Bool {
        guard let templateID = provider.templateId else { return false }
        return templateID == "codex" || templateID == "codexXcode"
    }

    public func modelsCacheURLs(for provider: Provider) -> [URL] {
        var urls: [URL] = []
        let providerSkillsFolder = STFolder(provider.defaultSkillsPath)
        let providerHome = STFolder(providerSkillsFolder.url.deletingLastPathComponent())
        let providerCache = STFile(providerHome.url.appendingPathComponent("models_cache.json"))
        urls.append(providerCache.url)

        let userCodexHome = STFolder("\(homeDirectoryPath())/.codex")
        let userCache = STFile(userCodexHome.url.appendingPathComponent("models_cache.json"))
        if userCache.url.path != providerCache.url.path {
            urls.append(userCache.url)
        }
        return urls
    }

    public func loadModelsCache(for provider: Provider) -> CodexModelsCacheSnapshot {
        guard supports(provider: provider) else {
            return .init(models: [], sourcePath: nil, fetchedAt: nil, clientVersion: nil, etag: nil)
        }
        for url in modelsCacheURLs(for: provider) {
            guard let cache = try? CodexModelsCache.load(from: url) else { continue }
            return .init(
                models: cache.models,
                sourcePath: url.path,
                fetchedAt: cache.fetchedAt,
                clientVersion: cache.clientVersion,
                etag: cache.etag
            )
        }
        return .init(models: [], sourcePath: nil, fetchedAt: nil, clientVersion: nil, etag: nil)
    }

    public func loadVisibleModelSlugs(for provider: Provider) -> [String] {
        guard supports(provider: provider) else { return [] }
        var result: [String] = []
        var seen: Set<String> = []
        for url in modelsCacheURLs(for: provider) {
            guard let cache = try? CodexModelsCache.load(from: url) else { continue }
            for model in cache.models {
                let slug = model.slug.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !slug.isEmpty else { continue }
                if model.visibility?.lowercased() == "hide" { continue }
                if seen.insert(slug).inserted {
                    result.append(slug)
                }
            }
        }
        return result
    }

    public func loadRelayModelProviderIDs(for provider: Provider) -> [String] {
        guard supports(provider: provider) else { return [] }
        let configFile = resolvedConfigFile(for: provider)
        guard configFile.isExists,
              let raw = try? configFile.read(),
              !raw.isEmpty
        else {
            return []
        }
        return Self.extractRelayModelProviderIDs(from: raw)
    }

    public func resolvedConfigFile(for provider: Provider) -> STFile {
        let rawSkillsPath = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        if !rawSkillsPath.isEmpty {
            let skillsFolder = STFolder(rawSkillsPath)
            let codexHome = STFolder(skillsFolder.url.deletingLastPathComponent())
            return STFile(codexHome.url.appendingPathComponent("config.toml"))
        }
        return STFile("\(homeDirectoryPath())/.codex/config.toml")
    }

    public func loadConfig(for provider: Provider) -> CodexMCPConfig? {
        guard supports(provider: provider) else { return nil }
        let configFile = resolvedConfigFile(for: provider)
        guard configFile.isExists else { return nil }
        guard let data = try? Data(contentsOf: configFile.url), !data.isEmpty else { return nil }
        return try? TOMLDecoder().decode(CodexMCPConfig.self, from: data)
    }

    public func loadConfiguredModel(for provider: Provider) -> String? {
        let trimmed = loadConfig(for: provider)?.model?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    public func loadConfiguredReasoningEffort(for provider: Provider) -> String? {
        let trimmed = loadConfig(for: provider)?.modelReasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    @discardableResult
    public func saveSelectedModel(
        _ model: String?,
        for provider: Provider,
        manager: CodexBinaryManager = .shared
    ) async throws -> String? {
        let trimmed = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = (trimmed?.isEmpty == false) ? trimmed : nil
        let configFile = resolvedConfigFile(for: provider)
        if let normalized {
            try await manager.applyModelToConfig(normalized, configFile: configFile)
        } else {
            try await manager.clearPreferredModel(configFile: configFile)
        }
        return normalized
    }

    private static func extractRelayModelProviderIDs(from raw: String) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        func append(_ candidate: String) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard seen.insert(trimmed).inserted else { return }
            result.append(trimmed)
        }

        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = extractQuotedValue(from: line, key: "model_provider") {
                append(value)
            }
            if let providerID = extractModelProviderSectionID(from: line) {
                append(providerID)
            }
        }

        return result
    }

    private static func extractQuotedValue(from line: String, key: String) -> String? {
        guard let separatorIndex = line.firstIndex(of: "=") else { return nil }
        let left = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard left == key else { return nil }
        let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.first == "\"", rawValue.last == "\"", rawValue.count >= 2 else { return nil }
        return String(rawValue.dropFirst().dropLast())
    }

    private static func extractModelProviderSectionID(from line: String) -> String? {
        let prefix = "[model_providers."
        let suffix = "]"
        guard line.hasPrefix(prefix), line.hasSuffix(suffix), line.count > prefix.count + suffix.count else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        let end = line.index(before: line.endIndex)
        return String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
