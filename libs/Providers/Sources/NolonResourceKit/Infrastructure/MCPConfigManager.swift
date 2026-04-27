import Foundation
import Darwin
import Network
import STFilePath
import TOML
import STJSON
import ProviderCatalog
import CodexProvider

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
    @discardableResult
    public static func repairProviderMCPStateIfNeeded(for template: ProviderTemplate) throws -> Bool {
        let cacheChanged = try repairCacheEntriesIfNeeded()
        guard template.supportsNativeMcpConfig else { return cacheChanged }
        let providerChanged = try repairProviderConfigIfNeeded(for: template)
        return cacheChanged || providerChanged
    }

    public static func listServers(for template: ProviderTemplate) throws -> [MCPServerInfo] {
        guard template.supportsNativeMcpConfig else { return [] }
        let servers = try effectiveServers(for: template)
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
        var projected = try effectiveServers(for: template)
        var server = projected[serverName] ?? [:]
        if enabled {
            server["disabled"] = nil
            server["enabled"] = true
        } else {
            server["enabled"] = nil
            server["disabled"] = true
        }
        server = sanitizeServerForProviderStorage(server, template: template)
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
        var projected = try effectiveServers(for: template)
        let base = projected[serverName] ?? [:]
        let merged = sanitizeServerForProviderStorage(
            normalizeServerConfigForStorage(base.merging(serverConfig, uniquingKeysWith: { _, new in new })),
            template: template
        )
        projected[serverName] = merged
        try writeCacheServer(name: serverName, server: merged, provider: template.rawValue, mergeProviders: true)
        try writeServersDict(for: template, servers: projected)
    }

    public static func removeServer(for template: ProviderTemplate, name: String) throws {
        guard template.supportsNativeMcpConfig else { return }
        let serverName = try validateComponent(name, field: "name")
        var projected = try effectiveServers(for: template)
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
        let servers = try effectiveServers(for: template)
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
        let servers = try effectiveServers(for: template)
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
        _ = try repairProviderMCPStateIfNeeded(for: template)
        var mergedServers = try readProviderServersDict(for: template)
        let entries = readCacheEntriesIndexedByName()
        var projectedManaged: [String: [String: Any]] = [:]
        let providerID = template.rawValue
        for name in entries.keys.sorted() {
            guard let entry = entries[name] else { continue }
            guard entry.isManaged(by: providerID) else { continue }
            let normalized = sanitizeServerForProviderStorage(
                normalizeServerConfigForStorage(entry.server),
                template: template
            )
            try writeCacheServer(
                name: name,
                server: normalized,
                provider: providerID,
                mergeProviders: true
            )
            projectedManaged[name] = projectedServerForProvider(normalized, template: template)
        }

        let previousManagedNames = readManagedProjectionNames(for: template)
        for name in previousManagedNames.subtracting(projectedManaged.keys) {
            mergedServers.removeValue(forKey: name)
        }
        for (name, server) in projectedManaged {
            mergedServers[name] = server
        }

        try writeServersDict(for: template, servers: mergedServers)
        try writeManagedProjectionNames(Set(projectedManaged.keys), for: template)
        return projectedManaged.count
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

        func isManaged(by provider: String) -> Bool {
            providers.contains(provider)
        }
    }

    static func effectiveServers(for template: ProviderTemplate) throws -> [String: [String: Any]] {
        var providerServers = try readProviderServersDict(for: template)
        let cacheEntries = readCacheEntriesIndexedByName()
        let providerID = template.rawValue

        // Read path must be side-effect free. Linked projection back to provider config
        // is handled explicitly via syncAllCacheServersToProvider(...).
        for (name, entry) in cacheEntries where entry.applies(to: providerID) {
            if let existing = providerServers[name] {
                providerServers[name] = existing.merging(entry.server, uniquingKeysWith: { _, cacheValue in cacheValue })
            } else {
                providerServers[name] = entry.server
            }
        }
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
            let renderedSection = renderCodexMCPServersSection(servers)
            _ = try CodexConfigStore(file: STFile(path)).update { existingText in
                replaceCodexMCPServersSection(in: existingText, with: renderedSection)
            }
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
        return sanitizeCanonicalServer(dict)
    }

    static func sanitizeCanonicalServer(_ input: [String: Any]) -> [String: Any] {
        var dict = input
        if dict["http_headers"] == nil, let legacyHeaders = dict["headers"] {
            dict["http_headers"] = legacyHeaders
        }
        dict.removeValue(forKey: "headers")
        let explicitType = (dict["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isStdio: Bool = {
            if let explicitType {
                return explicitType == "stdio" || explicitType == "local"
            }
            return dict["command"] != nil
        }()

        guard isStdio else { return dict }

        dict.removeValue(forKey: "url")
        dict.removeValue(forKey: "http_headers")
        dict.removeValue(forKey: "env_http_headers")
        dict.removeValue(forKey: "oauth_resource")
        dict.removeValue(forKey: "scopes")
        return dict
    }

    static func sanitizeServerForProviderStorage(
        _ input: [String: Any],
        template: ProviderTemplate
    ) -> [String: Any] {
        switch template {
        case .codex, .codexXcode:
            return sanitizeCodexServer(input)
        default:
            return input
        }
    }

    static func sanitizeCodexServer(_ input: [String: Any]) -> [String: Any] {
        sanitizeCanonicalServer(input)
    }

    static func projectedServerForProvider(
        _ input: [String: Any],
        template: ProviderTemplate
    ) -> [String: Any] {
        guard template == .codex || template == .codexXcode else { return input }
        guard shouldDisableUnavailableProjectedServer(input) else { return input }

        var disabled = input
        disabled["enabled"] = false
        disabled["disabled"] = nil
        return disabled
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
        return sanitizeCanonicalServer(dict)
    }

    static func readCacheEntriesIndexedByName() -> [String: CacheServerEntry] {
        let manager = currentManager()
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

    static func repairCacheEntriesIfNeeded() throws -> Bool {
        let entries = readCacheEntriesIndexedByName()
        var changed = false
        for (name, entry) in entries {
            let sanitized = normalizeServerConfigForStorage(entry.server)
            if canonicalJSON(entry.server) == canonicalJSON(sanitized) {
                continue
            }
            try writeCacheServer(name: name, server: sanitized, provider: nil, mergeProviders: false)
            changed = true
        }
        return changed
    }

    static func cacheEntry(for name: String) -> CacheServerEntry? {
        readCacheEntriesIndexedByName()[name]
    }

    static func cacheFileURL(for name: String) -> URL {
        currentManager().mcpsURL.appendingPathComponent("\(safeMcpCacheFileStem(for: name)).json")
    }

    static func managedProjectionStateURL(for template: ProviderTemplate) -> URL {
        let root = currentManager().rootURL
            .appendingPathComponent("mcp-projection-state", isDirectory: true)
        return root.appendingPathComponent("\(template.rawValue).json")
    }

    static func readManagedProjectionNames(for template: ProviderTemplate) -> Set<String> {
        let fileURL = managedProjectionStateURL(for: template)
        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let names = root["managed_server_names"] as? [String]
        else {
            return []
        }
        return Set(
            names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    static func writeManagedProjectionNames(_ names: Set<String>, for template: ProviderTemplate) throws {
        let fileURL = managedProjectionStateURL(for: template)
        _ = STFolder(fileURL.deletingLastPathComponent()).createIfNotExists()
        let root: [String: Any] = [
            "managed_server_names": names.sorted()
        ]
        let output = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if let existing = try? Data(contentsOf: fileURL), existing == output {
            return
        }
        try output.write(to: fileURL, options: .atomic)
    }

    static func repairProviderConfigIfNeeded(for template: ProviderTemplate) throws -> Bool {
        let current = try readProviderServersDict(for: template)
        guard !current.isEmpty else { return false }

        var repaired: [String: [String: Any]] = [:]
        var changed = false
        for (name, server) in current {
            let sanitized = sanitizeServerForProviderStorage(
                normalizeServerConfigForStorage(server),
                template: template
            )
            repaired[name] = sanitized
            if canonicalJSON(server) != canonicalJSON(sanitized) {
                changed = true
            }
        }

        guard changed else { return false }
        try writeServersDict(for: template, servers: repaired)
        return true
    }

    static func writeCacheServer(
        name: String,
        server: [String: Any],
        provider: String?,
        mergeProviders: Bool
    ) throws {
        let manager = currentManager()
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
        if entry.providers.isEmpty {
            try STFile(entry.fileURL).deleteIncludingBrokenSymlink()
            return
        }
        let data = try Data(contentsOf: entry.fileURL)
        var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        root["x-nolon"] = ["providers": entry.providers.sorted()]
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
        if let cwd = server.cwd { dict["cwd"] = cwd }
        if let env = server.env { dict["env"] = env }
        if let bearerTokenEnvVar = server.bearerTokenEnvVar { dict["bearer_token_env_var"] = bearerTokenEnvVar }
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
            cwd: dict["cwd"] as? String,
            env: (dict["env"] as? [String: String]) ?? (dict["env"] as? [String: Any])?.compactMapValues { $0 as? String },
            bearerTokenEnvVar: dict["bearer_token_env_var"] as? String,
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

    static func renderCodexMCPServersSection(_ servers: [String: [String: Any]]) -> String {
        guard !servers.isEmpty else { return "" }

        var sections: [String] = ["[mcp_servers]"]
        for name in servers.keys.sorted() {
            guard let rawServer = servers[name] else { continue }
            let server = normalizeServerConfigForStorage(rawServer)
            let rendered = renderCodexMCPServer(name: name, server: server)
            if !rendered.isEmpty {
                sections.append(rendered)
            }
        }
        return sections.joined(separator: "\n\n")
    }

    static func renderCodexMCPServer(name: String, server: [String: Any]) -> String {
        var lines = ["[mcp_servers.\(tomlTableKey(name))]"]
        let normalized = normalizeServerConfigForStorage(server)
        let explicitType = (normalized["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let inferredType: String? = {
            if normalized["command"] != nil { return "stdio" }
            if normalized["url"] != nil { return "http" }
            return nil
        }()
        let effectiveType = explicitType ?? inferredType

        if let url = normalized["url"] as? String {
            lines.append("url = \(tomlString(url))")
        }
        if let command = normalized["command"] as? String {
            lines.append("command = \(tomlString(command))")
        }
        if let args = (normalized["args"] as? [String]) ?? (normalized["args"] as? [Any])?.compactMap({ $0 as? String }),
           !args.isEmpty {
            lines.append("args = \(tomlArray(args.map(tomlString)))")
        }
        if let cwd = normalized["cwd"] as? String {
            lines.append("cwd = \(tomlString(cwd))")
        }
        if let env = (normalized["env"] as? [String: String]) ?? (normalized["env"] as? [String: Any])?.compactMapValues({ $0 as? String }),
           !env.isEmpty {
            lines.append("env = \(tomlInlineTable(env))")
        }
        if let bearerTokenEnvVar = normalized["bearer_token_env_var"] as? String {
            lines.append("bearer_token_env_var = \(tomlString(bearerTokenEnvVar))")
        }
        if let httpHeaders = (normalized["http_headers"] as? [String: String]) ?? (normalized["http_headers"] as? [String: Any])?.compactMapValues({ $0 as? String }),
           !httpHeaders.isEmpty {
            lines.append("http_headers = \(tomlInlineTable(httpHeaders))")
        }
        if let envHTTPHeaders = (normalized["env_http_headers"] as? [String: String]) ?? (normalized["env_http_headers"] as? [String: Any])?.compactMapValues({ $0 as? String }),
           !envHTTPHeaders.isEmpty {
            lines.append("env_http_headers = \(tomlInlineTable(envHTTPHeaders))")
        }
        if let oauthResource = normalized["oauth_resource"] as? String {
            lines.append("oauth_resource = \(tomlString(oauthResource))")
        }
        if let scopes = (normalized["scopes"] as? [String]) ?? (normalized["scopes"] as? [Any])?.compactMap({ $0 as? String }),
           !scopes.isEmpty {
            lines.append("scopes = \(tomlArray(scopes.map(tomlString)))")
        }
        if let enabledTools = (normalized["enabled_tools"] as? [String]) ?? (normalized["enabled_tools"] as? [Any])?.compactMap({ $0 as? String }),
           !enabledTools.isEmpty {
            lines.append("enabled_tools = \(tomlArray(enabledTools.map(tomlString)))")
        }
        if let disabledTools = (normalized["disabled_tools"] as? [String]) ?? (normalized["disabled_tools"] as? [Any])?.compactMap({ $0 as? String }),
           !disabledTools.isEmpty {
            lines.append("disabled_tools = \(tomlArray(disabledTools.map(tomlString)))")
        }
        if let envVars = (normalized["env_vars"] as? [String]) ?? (normalized["env_vars"] as? [Any])?.compactMap({ $0 as? String }),
           !envVars.isEmpty {
            lines.append("env_vars = \(tomlArray(envVars.map(tomlString)))")
        }
        if let required = normalized["required"] as? Bool {
            lines.append("required = \(required ? "true" : "false")")
        }
        if let startupTimeoutSec = numberValue(normalized["startup_timeout_sec"]) {
            lines.append("startup_timeout_sec = \(tomlNumber(startupTimeoutSec))")
        }
        if let startupTimeoutMs = numberValue(normalized["startup_timeout_ms"]) {
            lines.append("startup_timeout_ms = \(tomlNumber(startupTimeoutMs))")
        }
        if let toolTimeoutSec = numberValue(normalized["tool_timeout_sec"]) {
            lines.append("tool_timeout_sec = \(tomlNumber(toolTimeoutSec))")
        }
        if let type = explicitType,
           type != effectiveType || (type != "stdio" && type != "http") {
            lines.append("type = \(tomlString(type))")
        }
        if let transport = normalized["transport"] as? String {
            lines.append("transport = \(tomlString(transport))")
        }
        if let identity = (normalized["identity"] as? [String: String]) ?? (normalized["identity"] as? [String: Any])?.compactMapValues({ $0 as? String }),
           !identity.isEmpty {
            lines.append("identity = \(tomlInlineTable(identity))")
        }

        let isEnabled = MCPJsonFile.serverFields(from: normalized).isEnabled
        if !isEnabled {
            lines.append("enabled = false")
        }

        return lines.joined(separator: "\n")
    }

    static func shouldDisableUnavailableProjectedServer(_ server: [String: Any]) -> Bool {
        let fields = MCPJsonFile.serverFields(from: server)
        guard fields.isEnabled else { return false }

        if isUnavailableLoopbackHTTPServer(server) {
            return true
        }
        if isInvalidXcodeSessionBoundServer(server) {
            return true
        }
        return false
    }

    static func isUnavailableLoopbackHTTPServer(_ server: [String: Any]) -> Bool {
        guard let rawURL = server["url"] as? String,
              let url = URL(string: rawURL),
              let host = url.host?.lowercased(),
              host == "127.0.0.1" || host == "localhost"
        else {
            return false
        }

        let port: Int
        if let explicitPort = url.port {
            port = explicitPort
        } else if url.scheme?.lowercased() == "https" {
            port = 443
        } else {
            port = 80
        }

        return !isTCPPortReachable(host: host, port: port)
    }

    static func isInvalidXcodeSessionBoundServer(_ server: [String: Any]) -> Bool {
        let explicitType = (server["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isStdio = explicitType == "stdio" || (explicitType == nil && server["command"] != nil)
        guard isStdio else { return false }

        let env = (server["env"] as? [String: String]) ?? (server["env"] as? [String: Any])?.compactMapValues { $0 as? String } ?? [:]
        let pidValue = env["MCP_XCODE_PID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionValue = env["MCP_XCODE_SESSION_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSessionBinding = !(pidValue ?? "").isEmpty || !(sessionValue ?? "").isEmpty
        guard hasSessionBinding else { return false }
        guard let pidValue, !pidValue.isEmpty, let sessionValue, !sessionValue.isEmpty else { return true }
        guard let pid = Int32(pidValue), pid > 0 else { return true }
        return !processExists(pid: pid)
    }

    static func processExists(pid: Int32) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    static func isTCPPortReachable(host: String, port: Int, timeout: TimeInterval = 0.35) -> Bool {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }

        final class ReachabilityBox: @unchecked Sendable {
            var reachable = false
        }

        let semaphore = DispatchSemaphore(value: 0)
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        let queue = DispatchQueue(label: "nolon.mcp.reachability.\(host).\(port)")
        let box = ReachabilityBox()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                box.reachable = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: queue)
        let waitResult = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()
        return waitResult == .success && box.reachable
    }

    static func replaceCodexMCPServersSection(in text: String, with renderedSection: String) -> String {
        let normalizedInput = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedInput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var startIndex: Int?
        var endIndex = lines.count

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[mcp_servers") else { continue }
            guard trimmed == "[mcp_servers]" || (trimmed.hasPrefix("[mcp_servers.") && trimmed.hasSuffix("]")) else { continue }
            startIndex = index
            break
        }

        if let startIndex {
            for index in lines.index(after: startIndex)..<lines.count {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { continue }
                if trimmed == "[mcp_servers]" || trimmed.hasPrefix("[mcp_servers.") {
                    continue
                }
                endIndex = index
                break
            }

            var rebuilt = Array(lines[..<startIndex])
            if let last = rebuilt.last, !last.isEmpty {
                rebuilt.append("")
            }
            if !renderedSection.isEmpty {
                rebuilt.append(contentsOf: renderedSection.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
            }
            let trailing = Array(lines[endIndex...])
            if !trailing.isEmpty, !renderedSection.isEmpty, let last = rebuilt.last, !last.isEmpty, !(trailing.first?.isEmpty ?? true) {
                rebuilt.append("")
            }
            rebuilt.append(contentsOf: trailing)
            return trimTomlTrailingWhitespace(rebuilt.joined(separator: "\n"))
        }

        guard !renderedSection.isEmpty else { return trimTomlTrailingWhitespace(normalizedInput) }
        var result = normalizedInput
        if !result.isEmpty, !result.hasSuffix("\n") {
            result.append("\n")
        }
        if !result.isEmpty, !result.hasSuffix("\n\n") {
            result.append("\n")
        }
        result.append(renderedSection)
        return trimTomlTrailingWhitespace(result)
    }

    static func trimTomlTrailingWhitespace(_ text: String) -> String {
        let trimmed = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed + "\n"
    }

    static func tomlTableKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if !value.isEmpty,
           value.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return value
        }
        return tomlString(value)
    }

    static func tomlString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    static func tomlArray(_ values: [String]) -> String {
        "[\(values.joined(separator: ", "))]"
    }

    static func tomlInlineTable(_ values: [String: String]) -> String {
        let pairs = values.keys.sorted().compactMap { key -> String? in
            guard let value = values[key] else { return nil }
            return "\(tomlString(key)) = \(tomlString(value))"
        }
        return "{ \(pairs.joined(separator: ", ")) }"
    }

    static func tomlNumber(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(value)
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

    static func currentManager() -> NolonManager {
        NolonManager()
    }
}
