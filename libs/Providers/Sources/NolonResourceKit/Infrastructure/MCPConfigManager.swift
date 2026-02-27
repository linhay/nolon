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
        let servers = try readServersDict(for: template)
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
        let serverName = try validateComponent(name, field: "name")
        let path = template.defaultMcpConfigPath
        let ext = path.pathExtension.lowercased()
        if ext == "toml" {
            let data = try Data(contentsOf: path)
            var config = try TOMLDecoder().decode(CodexMCPConfig.self, from: data)
            if config.mcpServers == nil { config.mcpServers = [:] }
            var server = config.mcpServers?[serverName] ?? .init(url: nil, command: nil, args: nil, env: nil, enabled: nil)
            server.enabled = enabled
            config.mcpServers?[serverName] = server
            let output = try TOMLEncoder().encode(config)
            try output.write(to: path, options: .atomic)
            return
        }

        if template.rawValue == "opencode" {
            var root = try readJSONObject(fileURL: path)
            var mcp = root["mcp"] as? [String: Any] ?? [:]
            var raw = mcp[serverName] as? [String: Any] ?? [:]
            raw["enabled"] = enabled
            mcp[serverName] = raw
            root["mcp"] = mcp
            try writeJSONObject(root, to: path)
            return
        }

        var root = try readJSONObject(fileURL: path)
        var servers = (root["mcpServers"] as? [String: Any]) ?? (root["mcp_servers"] as? [String: Any]) ?? [:]
        var server = servers[serverName] as? [String: Any] ?? [:]
        if enabled {
            server["disabled"] = nil
            server["enabled"] = true
        } else {
            server["enabled"] = nil
            server["disabled"] = true
        }
        servers[serverName] = server
        root["mcpServers"] = servers
        root["mcp_servers"] = nil
        try writeJSONObject(root, to: path)
    }

    public static func upsertServer(
        for template: ProviderTemplate,
        name: String,
        serverConfig: [String: Any]
    ) throws {
        let serverName = try validateComponent(name, field: "name")
        let fields = MCPJsonFile.serverFields(from: serverConfig)
        let path = template.defaultMcpConfigPath
        let ext = path.pathExtension.lowercased()
        let configDir = STFolder(path.deletingLastPathComponent())
        _ = configDir.createIfNotExists()

        if ext == "toml" {
            var config: CodexMCPConfig
            if STFile(path).isExists,
               let data = try? Data(contentsOf: path),
               let parsed = try? TOMLDecoder().decode(CodexMCPConfig.self, from: data) {
                config = parsed
            } else {
                config = .init(model: nil, modelReasoningEffort: nil, projects: nil, notice: nil, mcpServers: [:])
            }
            var servers = config.mcpServers ?? [:]
            servers[serverName] = .init(
                url: fields.url,
                command: fields.command,
                args: fields.args,
                env: fields.env,
                enabled: fields.isEnabled
            )
            config.mcpServers = servers
            let output = try TOMLEncoder().encode(config)
            try output.write(to: path, options: .atomic)
            return
        }

        if template.rawValue == "opencode" {
            var root = try readJSONObject(fileURL: path)
            var mcp = root["mcp"] as? [String: Any] ?? [:]
            mcp[serverName] = encodeOpenCodeServer(from: serverConfig)
            root["mcp"] = mcp
            try writeJSONObject(root, to: path)
            return
        }

        var root = try readJSONObject(fileURL: path)
        var servers = (root["mcpServers"] as? [String: Any]) ?? (root["mcp_servers"] as? [String: Any]) ?? [:]
        servers[serverName] = normalizeServerConfigForStorage(serverConfig)
        root["mcpServers"] = servers
        root["mcp_servers"] = nil
        try writeJSONObject(root, to: path)
    }

    public static func removeServer(for template: ProviderTemplate, name: String) throws {
        let serverName = try validateComponent(name, field: "name")
        let path = template.defaultMcpConfigPath
        guard STFile(path).isExists else { return }

        let ext = path.pathExtension.lowercased()
        if ext == "toml" {
            let data = try Data(contentsOf: path)
            var config = try TOMLDecoder().decode(CodexMCPConfig.self, from: data)
            var servers = config.mcpServers ?? [:]
            servers[serverName] = nil
            config.mcpServers = servers
            let output = try TOMLEncoder().encode(config)
            try output.write(to: path, options: .atomic)
            return
        }

        if template.rawValue == "opencode" {
            var root = try readJSONObject(fileURL: path)
            var mcp = root["mcp"] as? [String: Any] ?? [:]
            mcp[serverName] = nil
            root["mcp"] = mcp
            try writeJSONObject(root, to: path)
            return
        }

        var root = try readJSONObject(fileURL: path)
        var servers = (root["mcpServers"] as? [String: Any]) ?? (root["mcp_servers"] as? [String: Any]) ?? [:]
        servers[serverName] = nil
        root["mcpServers"] = servers
        root["mcp_servers"] = nil
        try writeJSONObject(root, to: path)
    }

    public static func migrateServersToGlobalCache(
        for template: ProviderTemplate,
        overwrite: Bool
    ) throws -> MCPCacheMigrationResult {
        let manager = NolonManager.shared
        _ = STFolder(manager.mcpsURL).createIfNotExists()
        let servers = try readServersDict(for: template)
        var migrated = 0
        var skipped = 0
        var updated = 0

        for (name, raw) in servers {
            let stem = safeMcpCacheFileStem(for: name)
            let targetURL = manager.mcpsURL.appendingPathComponent("\(stem).json")
            let desiredServer = normalizeServerConfigForComparison(raw, name: name)
            if STFile(targetURL).isExists {
                if !overwrite {
                    skipped += 1
                    continue
                }
                if let existingData = try? Data(contentsOf: targetURL),
                   let existingServer = try? MCPJsonFile.serverConfig(from: existingData, slug: name),
                   canonicalJSON(existingServer) == canonicalJSON(desiredServer) {
                    skipped += 1
                    continue
                }
                let data = try buildCacheFile(name: name, server: desiredServer)
                try data.write(to: targetURL, options: .atomic)
                updated += 1
                continue
            }

            let data = try buildCacheFile(name: name, server: desiredServer)
            try data.write(to: targetURL, options: .atomic)
            migrated += 1
        }

        return MCPCacheMigrationResult(migrated: migrated, skipped: skipped, updated: updated)
    }

    public static func cacheStatus(for template: ProviderTemplate, name: String? = nil) throws -> [MCPCacheStatusInfo] {
        let manager = NolonManager.shared
        let servers = try readServersDict(for: template)
        let filtered: [String: [String: Any]]
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalized = try validateComponent(name, field: "name")
            filtered = servers.filter { $0.key == normalized }
        } else {
            filtered = servers
        }

        let sortedNames = filtered.keys.sorted()
        return sortedNames.map { serverName in
            let targetURL = manager.mcpsURL.appendingPathComponent("\(safeMcpCacheFileStem(for: serverName)).json")
            guard STFile(targetURL).isExists else {
                return MCPCacheStatusInfo(name: serverName, state: .notMigrated, cachePath: targetURL.path)
            }
            let desired = normalizeServerConfigForComparison(filtered[serverName] ?? [:], name: serverName)
            let state: MCPCacheState
            if let existingData = try? Data(contentsOf: targetURL),
               let existingServer = try? MCPJsonFile.serverConfig(from: existingData, slug: serverName),
               canonicalJSON(existingServer) == canonicalJSON(desired) {
                state = .migratedUpToDate
            } else {
                state = .migratedNeedsUpdate
            }
            return MCPCacheStatusInfo(name: serverName, state: state, cachePath: targetURL.path)
        }
    }
}

private extension MCPConfigManager {
    static func readServersDict(for template: ProviderTemplate) throws -> [String: [String: Any]] {
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
                var dict: [String: Any] = [:]
                if let url = server.url { dict["url"] = url }
                if let command = server.command { dict["command"] = command }
                if let args = server.args { dict["args"] = args }
                if let env = server.env { dict["env"] = env }
                if let enabled = server.enabled { dict["enabled"] = enabled }
                result[name] = dict
            }
            return result
        }

        let root = try readJSONObject(fileURL: path)
        if template.rawValue == "opencode" {
            let mcp = root["mcp"] as? [String: Any] ?? [:]
            var result: [String: [String: Any]] = [:]
            for (name, value) in mcp {
                result[name] = decodeOpenCodeServer(value)
            }
            return result
        }

        let servers = (root["mcpServers"] as? [String: Any]) ?? (root["mcp_servers"] as? [String: Any]) ?? [:]
        return servers.compactMapValues { $0 as? [String: Any] }
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

    static func buildCacheFile(name: String, server: [String: Any]) throws -> Data {
        let root: [String: Any] = ["mcpServers": [name: server]]
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
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
