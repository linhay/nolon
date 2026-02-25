import Foundation
import ProviderCatalog
import STFilePath
import STJSON

public struct ProviderMCPSnapshot: Sendable {
    public let mcps: [MCP]
    public let cacheStates: [String: MCPCacheState]

    public init(mcps: [MCP], cacheStates: [String: MCPCacheState]) {
        self.mcps = mcps
        self.cacheStates = cacheStates
    }
}

public final class ProviderMCPMaintenanceService: @unchecked Sendable {
    private let manager: NolonManager

    public init(manager: NolonManager = .shared) {
        self.manager = manager
    }

    public func listServers(template: ProviderTemplate) throws -> [MCPServerInfo] {
        try MCPConfigManager.listServers(for: template)
    }

    public func listSnapshot(template: ProviderTemplate) throws -> ProviderMCPSnapshot {
        let servers = try listServers(template: template)
        let mcps = servers.map { server -> MCP in
            var dict: [String: Any] = [:]
            if let url = server.url { dict["url"] = url }
            if let command = server.command { dict["command"] = command }
            if let args = server.args, !args.isEmpty { dict["args"] = args }
            if let env = server.env, !env.isEmpty { dict["env"] = env }
            dict["enabled"] = server.isEnabled
            return MCP(name: server.name, json: AnyCodable(dict))
        }.sorted { $0.name < $1.name }

        let status = try MCPConfigManager.cacheStatus(for: template)
        let statusMap = Dictionary(uniqueKeysWithValues: status.map { ($0.name, $0.state) })
        var states: [String: MCPCacheState] = [:]
        for mcp in mcps {
            states[mcp.name] = statusMap[mcp.name] ?? .notMigrated
        }
        return ProviderMCPSnapshot(mcps: mcps, cacheStates: states)
    }

    public func setEnabled(template: ProviderTemplate, name: String, enabled: Bool) throws {
        try MCPConfigManager.setEnabled(for: template, name: name, enabled: enabled)
    }

    public func upsertServer(
        template: ProviderTemplate,
        name: String,
        serverConfig: [String: Any]
    ) throws {
        try MCPConfigManager.upsertServer(for: template, name: name, serverConfig: serverConfig)
    }

    public func upsertMCP(template: ProviderTemplate, mcp: MCP) throws {
        try upsertServer(template: template, name: mcp.name, serverConfig: mcp.dictionaryValue)
    }

    public func removeServer(template: ProviderTemplate, name: String) throws {
        try MCPConfigManager.removeServer(for: template, name: name)
    }

    public func migrateServersToGlobalCache(
        template: ProviderTemplate,
        overwrite: Bool
    ) throws -> MCPCacheMigrationResult {
        try MCPConfigManager.migrateServersToGlobalCache(for: template, overwrite: overwrite)
    }

    public func cacheStatus(template: ProviderTemplate, name: String? = nil) throws -> [MCPCacheStatusInfo] {
        try MCPConfigManager.cacheStatus(for: template, name: name)
    }

    public func migrateMcpToGlobalCache(_ mcp: MCP) throws {
        _ = manager.mcpsFolder.createIfNotExists()
        let target = mcpCacheFileURL(for: mcp.name)
        guard !target.isExists else { return }
        let desired = normalizedServerConfigForComparison(mcp.dictionaryValue)
        let data = try buildCacheFile(name: mcp.name, server: desired)
        try data.write(to: target.url, options: .atomic)
    }

    public func updateCachedMcpIfNeeded(_ mcp: MCP) throws {
        _ = manager.mcpsFolder.createIfNotExists()
        let target = mcpCacheFileURL(for: mcp.name)
        let desired = normalizedServerConfigForComparison(mcp.dictionaryValue)

        guard target.isExists else {
            let data = try buildCacheFile(name: mcp.name, server: desired)
            try data.write(to: target.url, options: .atomic)
            return
        }

        let existingData = try Data(contentsOf: target.url)
        let existingServer = (try? MCPJsonFile.serverConfig(from: existingData, slug: mcp.name)) ?? [:]
        if canonicalJSON(existingServer) == canonicalJSON(desired) {
            return
        }

        let data = try buildCacheFile(name: mcp.name, server: desired)
        try data.write(to: target.url, options: .atomic)
    }
}

private extension ProviderMCPMaintenanceService {
    func mcpCacheFileURL(for name: String) -> STFile {
        manager.mcpsFolder.file("\(safeMcpCacheFileStem(for: name)).json")
    }

    func safeMcpCacheFileStem(for name: String) -> String {
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

    func normalizedServerConfigForComparison(_ input: [String: Any]) -> [String: Any] {
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
        return dict
    }

    func buildCacheFile(name: String, server: [String: Any]) throws -> Data {
        let root: [String: Any] = ["mcpServers": [name: server]]
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    func canonicalJSON(_ object: Any) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
}
