import Foundation
import STFilePath
import TOML
import STJSON
import ProviderCatalog

public enum MCPCacheState: String, Sendable, Equatable {
    case notMigrated
    case migratedUpToDate
    case migratedNeedsUpdate
}

public struct MCPServerInfo: Sendable, Equatable {
    public let name: String
    public let url: String?
    public let command: String?
    public let args: [String]?
    public let env: [String: String]?
    public let isEnabled: Bool
}

public struct MCPCacheStatusInfo: Sendable, Equatable {
    public let name: String
    public let state: MCPCacheState
    public let cachePath: String
}

public struct MCPCacheMigrationResult: Sendable, Equatable {
    public let migrated: Int
    public let skipped: Int
    public let updated: Int
}

public enum MCPConfigManager {
    public static func listServers(for template: ProviderTemplate) throws -> [MCPServerInfo] {
        guard template.supportsNativeMcpConfig else { return [] }
        let servers = try synchronizedServers(for: template)
        return servers.keys.sorted().map { name in
            let fields = MCPJsonFile.serverFields(from: servers[name] ?? [:])
            return MCPServerInfo(
                name: name,
                url: fields.url,
                command: fields.command,
                args: fields.args,
                env: fields.env,
                isEnabled: fields.isEnabled
            )
        }
    }

    public static func setEnabled(for template: ProviderTemplate, name: String, enabled: Bool) throws {
        guard template.supportsNativeMcpConfig else { return }
        let serverName = try validateComponent(name, field: "name")
        var projected = try synchronizedServers(for: template)
        var server = projected[serverName] ?? [:]
        if enabled {
            server["disabled"] = nil
            server["enabled"] = true
        } else {
            server["enabled"] = nil
            server["disabled"] = true
        }
        projected[serverName] = server
        try writeCacheServer(name: serverName, server: server, provider: template.rawValue, mergeProviders: true)
        try writeServersDict(for: template, servers: projected)
    }

    public static func upsertServer(
        for template: ProviderTemplate,
        name: String,
        serverConfig: [String: Any]
    ) throws {
        guard template.supportsNativeMcpConfig else { return }
        let serverName = try validateComponent(name, field: "name")
        var projected = try synchronizedServers(for: template)
        let base = projected[serverName] ?? [:]
        let merged = normalizeServerConfigForStorage(base.merging(serverConfig, uniquingKeysWith: { _, new in new }))
        projected[serverName] = merged
        try writeCacheServer(name: serverName, server: merged, provider: template.rawValue, mergeProviders: true)
        try writeServersDict(for: template, servers: projected)
    }

    public static func removeServer(for template: ProviderTemplate, name: String) throws {
        guard template.supportsNativeMcpConfig else { return }
        let serverName = try validateComponent(name, field: "name")
        var projected = try synchronizedServers(for: template)
        projected[serverName] = nil
        try writeServersDict(for: template, servers: projected)
        try unbindProviderFromCacheServer(name: serverName, provider: template.rawValue)
    }

    public static func migrateServersToGlobalCache(
        for template: ProviderTemplate,
        overwrite: Bool
    ) throws -> MCPCacheMigrationResult {
        guard template.supportsNativeMcpConfig else {
            return MCPCacheMigrationResult(migrated: 0, skipped: 0, updated: 0)
        }
        let servers = try synchronizedServers(for: template)
        var migrated = 0
        var skipped = 0
        var updated = 0

        for (name, raw) in servers {
            let existing = cacheEntry(for: name)
            if existing != nil, !overwrite {
                skipped += 1
                continue
            }

            let desired = normalizeServerConfigForComparison(raw, name: name)
            if let existing, canonicalJSON(existing.server) == canonicalJSON(desired) {
                if existing.providers.contains(template.rawValue) || existing.providers.isEmpty {
                    skipped += 1
                    continue
                }
            }

            try writeCacheServer(name: name, server: desired, provider: template.rawValue, mergeProviders: true)
            if existing == nil {
                migrated += 1
            } else {
                updated += 1
            }
        }

        return MCPCacheMigrationResult(migrated: migrated, skipped: skipped, updated: updated)
    }

    public static func cacheStatus(for template: ProviderTemplate, name: String? = nil) throws -> [MCPCacheStatusInfo] {
        guard template.supportsNativeMcpConfig else { return [] }
        let servers = try synchronizedServers(for: template)
        let filtered: [String: [String: Any]]
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalized = try validateComponent(name, field: "name")
            filtered = servers.filter { $0.key == normalized }
        } else {
            filtered = servers
        }

        let sortedNames = filtered.keys.sorted()
        return sortedNames.map { serverName in
            let targetURL = cacheFileURL(for: serverName)
            guard let entry = cacheEntry(for: serverName),
                  entry.applies(to: template.rawValue)
            else {
                return MCPCacheStatusInfo(name: serverName, state: .notMigrated, cachePath: targetURL.path)
            }

            let desired = normalizeServerConfigForComparison(filtered[serverName] ?? [:], name: serverName)
            let state: MCPCacheState = canonicalJSON(entry.server) == canonicalJSON(desired)
                ? .migratedUpToDate
                : .migratedNeedsUpdate
            return MCPCacheStatusInfo(name: serverName, state: state, cachePath: targetURL.path)
        }
    }

    /// For linked-provider mode: project all fragment files from ~/.nolon/mcps to this provider's
    /// native MCP config and bind provider ownership metadata into each fragment.
    @discardableResult
    public static func syncAllCacheServersToProvider(for template: ProviderTemplate) throws -> Int {
        guard template.supportsNativeMcpConfig else { return 0 }
        let entries = readCacheEntriesIndexedByName()
        var projected: [String: [String: Any]] = [:]
        for (name, entry) in entries {
            let normalized = normalizeServerConfigForStorage(entry.server)
            projected[name] = normalized
            try writeCacheServer(
                name: name,
                server: normalized,
                provider: template.rawValue,
                mergeProviders: true
            )
        }
        try writeServersDict(for: template, servers: projected)
        return projected.count
    }
}

private extension MCPConfigManager {
    struct CacheServerEntry {
        let name: String
        let server: [String: Any]
        var providers: Set<String>
        let fileURL: URL

        func applies(to provider: String) -> Bool {
            providers.isEmpty || providers.contains(provider)
        }
    }

    static func synchronizedServers(for template: ProviderTemplate) throws -> [String: [String: Any]] {
        var providerServers = try readProviderServersDict(for: template)
        let cacheEntries = readCacheEntriesIndexedByName()
        let providerID = template.rawValue

        // Import provider-native entries into fragment source when missing.
        for (name, server) in providerServers where cacheEntries[name] == nil {
            try writeCacheServer(name: name, server: server, provider: providerID, mergeProviders: true)
        }

        let refreshedCacheEntries = readCacheEntriesIndexedByName()

        // Fragment source is authoritative for entries bound to this provider.
        for (name, entry) in refreshedCacheEntries where entry.applies(to: providerID) {
            if let existing = providerServers[name] {
                providerServers[name] = existing.merging(entry.server, uniquingKeysWith: { _, cacheValue in cacheValue })
            } else {
                providerServers[name] = entry.server
            }
        }

        try writeServersDict(for: template, servers: providerServers)
        return providerServers
    }

    static func readProviderServersDict(for template: ProviderTemplate) throws -> [String: [String: Any]] {
        let path = template.defaultMcpConfigPath
        guard STFile(path).isExists else { return [:] }
        let ext = path.pathExtension.lowercased()

        if ext == "toml" {
            let data = try Data(contentsOf: path)
            if data.isEmpty { return [:] }
            let config = try TOMLDecoder().decode(CodexMCPConfig.self, from: data)
            let servers = config.mcpServers ?? [:]
            var result: [String: [String: Any]] = [:]
            for (name, server) in servers {
                result[name] = codexServerDictionary(server)
            }
            return result
        }

        let root = try readJSONObject(fileURL: path)
        if template.rawValue == "opencode" {
            let mcp = root["mcp"] as? [String: Any] ?? [:]
            return mcp.compactMapValues { decodeOpenCodeServer($0) }
        }

        if template.rawValue == "copilot",
           let servers = root["servers"] as? [String: Any] {
            return servers.compactMapValues { $0 as? [String: Any] }
        }

        if let servers = (root["mcpServers"] as? [String: Any]) ?? (root["mcp_servers"] as? [String: Any]) {
            return servers.compactMapValues { $0 as? [String: Any] }
        }

        if let mcp = root["mcp"] as? [String: Any] {
            return mcp.compactMapValues { $0 as? [String: Any] }
        }

        return [:]
    }

    static func writeServersDict(for template: ProviderTemplate, servers: [String: [String: Any]]) throws {
        let path = template.defaultMcpConfigPath
        let ext = path.pathExtension.lowercased()
        _ = STFolder(path.deletingLastPathComponent()).createIfNotExists()

        if ext == "toml" {
            var config: CodexMCPConfig
            if STFile(path).isExists,
               let data = try? Data(contentsOf: path),
               let parsed = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data) {
                config = parsed
            } else {
                config = .init(model: nil, modelReasoningEffort: nil, projects: nil, notice: nil, mcpServers: [:])
            }
            var mapped: [String: CodexMCPServer] = [:]
            for (name, server) in servers {
                mapped[name] = codexServer(from: server)
            }
            let existingMapped = (config.mcpServers ?? [:]).mapValues(codexServerDictionary)
            let desiredMapped = mapped.mapValues(codexServerDictionary)
            if canonicalJSON(existingMapped) == canonicalJSON(desiredMapped) {
                return
            }
            config.mcpServers = mapped
            let output = try TOMLEncoder().encode(config)
            if let existing = try? Data(contentsOf: path), existing == output {
                return
            }
            try output.write(to: path, options: .atomic)
            return
        }

        if template.rawValue == "opencode" {
            var root = try readJSONObject(fileURL: path)
            var mapped: [String: Any] = [:]
            for (name, server) in servers {
                mapped[name] = encodeOpenCodeServer(from: server)
            }
            root["mcp"] = mapped
            try writeJSONObjectIfChanged(root, to: path)
            return
        }

        var root = try readJSONObject(fileURL: path)
        var mapped: [String: Any] = [:]
        for (name, server) in servers {
            mapped[name] = normalizeServerConfigForStorage(server)
        }
        let key = preferredServersKey(for: template, root: root)
        root["servers"] = nil
        root["mcpServers"] = nil
        root["mcp_servers"] = nil
        root["mcp"] = nil
        root[key] = mapped
        try writeJSONObjectIfChanged(root, to: path)
    }

    static func preferredServersKey(for template: ProviderTemplate, root: [String: Any]) -> String {
        if template.rawValue == "copilot" {
            if root["servers"] != nil { return "servers" }
            if root["mcpServers"] != nil { return "mcpServers" }
            if root["mcp_servers"] != nil { return "mcp_servers" }
            return "servers"
        }
        if root["mcp_servers"] != nil, root["mcpServers"] == nil {
            return "mcp_servers"
        }
        return "mcpServers"
    }

    static func decodeOpenCodeServer(_ value: Any) -> [String: Any] {
        guard let dict = value as? [String: Any] else { return [:] }
        var result: [String: Any] = [:]

        let type = (dict["type"] as? String)?.lowercased()
        if type == "remote" || dict["url"] != nil {
            if let url = dict["url"] as? String { result["url"] = url }
            result["type"] = "http"
        } else {
            result["type"] = "stdio"
            if let commandArray = dict["command"] as? [Any] {
                let parts = commandArray.compactMap { $0 as? String }
                if let first = parts.first {
                    result["command"] = first
                    let rest = Array(parts.dropFirst())
                    if !rest.isEmpty { result["args"] = rest }
                }
            } else if let command = dict["command"] as? String {
                result["command"] = command
            }
        }

        if let env = dict["environment"] as? [String: Any] {
            result["env"] = env.compactMapValues { $0 as? String }
        } else if let env = dict["env"] as? [String: Any] {
            result["env"] = env.compactMapValues { $0 as? String }
        }
        if let enabled = dict["enabled"] as? Bool {
            result["enabled"] = enabled
        }

        // Preserve unknown fields in canonical payload.
        for (key, value) in dict where result[key] == nil && key != "environment" {
            result[key] = value
        }

        return result
    }

    static func encodeOpenCodeServer(from server: [String: Any]) -> [String: Any] {
        let fields = MCPJsonFile.serverFields(from: server)
        var result: [String: Any] = [:]
        let type = (server["type"] as? String)?.lowercased()
        if type == "http" || type == "remote" || fields.url != nil {
            result["type"] = "remote"
            if let url = fields.url { result["url"] = url }
        } else {
            result["type"] = "local"
            let parts = [fields.command].compactMap { $0 } + (fields.args ?? [])
            if !parts.isEmpty { result["command"] = parts }
        }
        if let env = fields.env, !env.isEmpty { result["environment"] = env }
        result["enabled"] = fields.isEnabled

        for (key, value) in server where result[key] == nil && key != "env" {
            result[key] = value
        }

        return result
    }

    static func normalizeServerConfigForStorage(_ input: [String: Any]) -> [String: Any] {
        var dict = input
        let fields = MCPJsonFile.serverFields(from: dict)
        if fields.isEnabled {
            dict["disabled"] = nil
            dict["enabled"] = true
        } else {
            dict["enabled"] = nil
            dict["disabled"] = true
        }
        return dict
    }

    static func normalizeServerConfigForComparison(_ input: [String: Any], name: String) -> [String: Any] {
        var dict = input
        let fields = MCPJsonFile.serverFields(from: dict)
        dict.removeValue(forKey: "enabled")
        if fields.isEnabled {
            dict.removeValue(forKey: "disabled")
        } else {
            dict["disabled"] = true
        }
        if dict["type"] == nil {
            if dict["command"] != nil {
                dict["type"] = "stdio"
            } else if dict["url"] != nil {
                dict["type"] = "http"
            }
        }
        _ = name
        return dict
    }

    static func readCacheEntriesIndexedByName() -> [String: CacheServerEntry] {
        let manager = NolonManager.shared
        _ = manager.mcpsFolder.createIfNotExists()
        guard let files = try? manager.mcpsFolder.files() else { return [:] }
        var result: [String: CacheServerEntry] = [:]
        for file in files where file.url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: file.url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = (root["mcpServers"] as? [String: Any]) ?? (root["mcp_servers"] as? [String: Any])
            else { continue }

            let providers: Set<String> = {
                guard let nolon = root["x-nolon"] as? [String: Any],
                      let rawProviders = nolon["providers"] as? [String]
                else { return [] }
                return Set(rawProviders.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            }()

            for (name, value) in servers {
                guard let server = value as? [String: Any] else { continue }
                result[name] = CacheServerEntry(name: name, server: server, providers: providers, fileURL: file.url)
            }
        }
        return result
    }

    static func cacheEntry(for name: String) -> CacheServerEntry? {
        readCacheEntriesIndexedByName()[name]
    }

    static func cacheFileURL(for name: String) -> URL {
        NolonManager.shared.mcpsURL.appendingPathComponent("\(safeMcpCacheFileStem(for: name)).json")
    }

    static func writeCacheServer(
        name: String,
        server: [String: Any],
        provider: String?,
        mergeProviders: Bool
    ) throws {
        let manager = NolonManager.shared
        _ = manager.mcpsFolder.createIfNotExists()
        let fileURL = cacheFileURL(for: name)
        var root: [String: Any] = [:]
        var providers = Set<String>()

        if let data = try? Data(contentsOf: fileURL),
           let existingRoot = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existingRoot
            if let nolon = existingRoot["x-nolon"] as? [String: Any],
               let rawProviders = nolon["providers"] as? [String] {
                providers = Set(rawProviders)
            }
        }

        if mergeProviders, let provider, !provider.isEmpty {
            providers.insert(provider)
        }

        root["mcpServers"] = [name: normalizeServerConfigForComparison(server, name: name)]
        root["mcp_servers"] = nil
        if !providers.isEmpty {
            root["x-nolon"] = ["providers": providers.sorted()]
        }
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if let existing = try? Data(contentsOf: fileURL), existing == data {
            return
        }
        try data.write(to: fileURL, options: .atomic)
    }

    static func unbindProviderFromCacheServer(name: String, provider: String) throws {
        guard var entry = cacheEntry(for: name) else { return }
        guard !entry.providers.isEmpty else { return } // legacy/global entry: keep as-is
        entry.providers.remove(provider)
        let data = try Data(contentsOf: entry.fileURL)
        var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if entry.providers.isEmpty {
            root["x-nolon"] = nil
        } else {
            root["x-nolon"] = ["providers": entry.providers.sorted()]
        }
        let output = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try output.write(to: entry.fileURL, options: .atomic)
    }

    static func codexServerDictionary(_ server: CodexMCPServer) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let url = server.url { dict["url"] = url }
        if let command = server.command { dict["command"] = command }
        if let args = server.args { dict["args"] = args }
        if let env = server.env { dict["env"] = env }
        if let enabled = server.enabled { dict["enabled"] = enabled }
        if let enabledTools = server.enabledTools { dict["enabled_tools"] = enabledTools }
        if let disabledTools = server.disabledTools { dict["disabled_tools"] = disabledTools }
        if let envVars = server.envVars { dict["env_vars"] = envVars }
        if let httpHeaders = server.httpHeaders { dict["http_headers"] = httpHeaders }
        if let envHTTPHeaders = server.envHTTPHeaders { dict["env_http_headers"] = envHTTPHeaders }
        if let oauthResource = server.oauthResource { dict["oauth_resource"] = oauthResource }
        if let scopes = server.scopes { dict["scopes"] = scopes }
        if let required = server.required { dict["required"] = required }
        if let startupTimeoutSec = server.startupTimeoutSec { dict["startup_timeout_sec"] = startupTimeoutSec }
        if let startupTimeoutMs = server.startupTimeoutMs { dict["startup_timeout_ms"] = startupTimeoutMs }
        if let toolTimeoutSec = server.toolTimeoutSec { dict["tool_timeout_sec"] = toolTimeoutSec }
        if let type = server.type { dict["type"] = type }
        if let transport = server.transport { dict["transport"] = transport }
        if let identity = server.identity { dict["identity"] = identity }
        return dict
    }

    static func codexServer(from dict: [String: Any]) -> CodexMCPServer {
        CodexMCPServer(
            url: dict["url"] as? String,
            command: dict["command"] as? String,
            args: (dict["args"] as? [String]) ?? (dict["args"] as? [Any])?.compactMap { $0 as? String },
            env: (dict["env"] as? [String: String]) ?? (dict["env"] as? [String: Any])?.compactMapValues { $0 as? String },
            enabled: {
                if let enabled = dict["enabled"] as? Bool { return enabled }
                if let disabled = dict["disabled"] as? Bool { return !disabled }
                return nil
            }(),
            enabledTools: dict["enabled_tools"] as? [String],
            disabledTools: dict["disabled_tools"] as? [String],
            envVars: dict["env_vars"] as? [String],
            httpHeaders: (dict["http_headers"] as? [String: String]) ?? (dict["http_headers"] as? [String: Any])?.compactMapValues { $0 as? String },
            envHTTPHeaders: (dict["env_http_headers"] as? [String: String]) ?? (dict["env_http_headers"] as? [String: Any])?.compactMapValues { $0 as? String },
            oauthResource: dict["oauth_resource"] as? String,
            scopes: dict["scopes"] as? [String],
            required: dict["required"] as? Bool,
            startupTimeoutSec: numberValue(dict["startup_timeout_sec"]),
            startupTimeoutMs: numberValue(dict["startup_timeout_ms"]),
            toolTimeoutSec: numberValue(dict["tool_timeout_sec"]),
            type: dict["type"] as? String,
            transport: dict["transport"] as? String,
            identity: (dict["identity"] as? [String: String]) ?? (dict["identity"] as? [String: Any])?.compactMapValues { $0 as? String }
        )
    }

    static func numberValue(_ raw: Any?) -> Double? {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) }
        return nil
    }

    static func safeMcpCacheFileStem(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UUID().uuidString }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ ."))
        let mapped = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        var result = String(mapped)
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
        return result.isEmpty ? UUID().uuidString : result
    }

    static func canonicalJSON(_ object: Any) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func readJSONObject(fileURL: URL) throws -> [String: Any] {
        guard STFile(fileURL).isExists else { return [:] }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    static func writeJSONObject(_ object: [String: Any], to fileURL: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: fileURL, options: .atomic)
    }

    static func writeJSONObjectIfChanged(_ object: [String: Any], to fileURL: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if let existing = try? Data(contentsOf: fileURL), existing == data {
            return
        }
        try data.write(to: fileURL, options: .atomic)
    }

    static func validateComponent(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "nolon.mcp.config", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(field) cannot be empty"])
        }
        let candidateURL = URL(fileURLWithPath: trimmed)
        let basename = candidateURL.lastPathComponent
        guard basename == trimmed, trimmed != ".", trimmed != ".." else {
            throw NSError(domain: "nolon.mcp.config", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(field) must be a single path component: \(value)"])
        }
        return trimmed
    }
}
