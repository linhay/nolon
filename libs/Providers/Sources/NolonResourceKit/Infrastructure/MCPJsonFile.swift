import Foundation
import STJSON

/// Helpers for working with "mcp.json"-style configuration files.
///
/// Nolon treats cached MCP files under `~/.nolon/mcps/*.json` as a JSON document that contains
/// a top-level `mcpServers` object.
public enum MCPJsonFile {

    public enum Error: Swift.Error {
        case invalidJson
        case missingServerConfig
    }

    /// Normalize an arbitrary MCP JSON payload into a standard `mcpServers`-based document.
    ///
    /// Supported inputs:
    /// - `{ "mcpServers": { ... } }` (or legacy `{ "mcp_servers": { ... } }`)
    /// - `{ "command": "...", "args": [...], "env": { ... } }` (single server config)
    public nonisolated static func normalizedData(
        from input: Data,
        slug: String,
        name: String? = nil,
        description: String? = nil
    ) throws -> Data {
        guard let raw = try? JSONSerialization.jsonObject(with: input) else {
            throw Error.invalidJson
        }

        var root: [String: Any] = [:]

        if let dict = raw as? [String: Any] {
            if let servers = (dict["mcpServers"] as? [String: Any]) ?? (dict["mcp_servers"] as? [String: Any]) {
                root = dict
                root["mcpServers"] = servers
                root["mcp_servers"] = nil
            } else {
                root["mcpServers"] = [slug: dict]
            }

            if root["name"] == nil, let name { root["name"] = name }
            if root["description"] == nil, let description { root["description"] = description }
        } else {
            root["mcpServers"] = [slug: raw]
            if let name { root["name"] = name }
            if let description { root["description"] = description }
        }

        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    /// Extract a single MCP server config object from a normalized (or legacy) MCP JSON payload.
    ///
    /// - If `mcpServers[slug]` exists, returns it.
    /// - If `mcpServers` contains exactly one server, returns that server.
    /// - Otherwise throws.
    public nonisolated static func serverConfig(from data: Data, slug: String) throws -> [String: Any] {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidJson
        }

        let servers = (raw["mcpServers"] as? [String: Any]) ?? (raw["mcp_servers"] as? [String: Any]) ?? [:]
        if let dict = servers[slug] as? [String: Any] {
            return dict
        }
        if servers.count == 1, let only = servers.values.first as? [String: Any] {
            return only
        }

        // Legacy: treat the root itself as the server config if it looks like one.
        if raw["command"] != nil || raw["args"] != nil || raw["env"] != nil || raw["url"] != nil {
            return raw
        }

        throw Error.missingServerConfig
    }

    public nonisolated static func metadata(from data: Data) -> (name: String?, description: String?) {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }
        return (raw["name"] as? String, raw["description"] as? String)
    }

    public nonisolated static func serverFields(from serverConfig: [String: Any]) -> (url: String?, command: String?, args: [String]?, env: [String: String]?, isEnabled: Bool) {
        let url = serverConfig["url"] as? String
        let command = serverConfig["command"] as? String

        let args: [String]? = (serverConfig["args"] as? [String]) ?? (serverConfig["args"] as? [Any])?.compactMap { $0 as? String }
        let env: [String: String]? = (serverConfig["env"] as? [String: String]) ?? (serverConfig["env"] as? [String: Any])?.compactMapValues { $0 as? String }

        if let enabled = serverConfig["enabled"] as? Bool {
            return (url, command, args, env, enabled)
        }
        if let disabled = serverConfig["disabled"] as? Bool {
            return (url, command, args, env, !disabled)
        }
        return (url, command, args, env, true)
    }
}
