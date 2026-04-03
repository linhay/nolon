import Foundation

public struct CodexMCPConfig: Codable, Sendable {
    public var model: String?
    public var modelReasoningEffort: String?
    public var projects: [String: CodexProject]?
    public var notice: CodexNotice?
    public var mcpServers: [String: CodexMCPServer]?

    enum CodingKeys: String, CodingKey {
        case model
        case modelReasoningEffort = "model_reasoning_effort"
        case projects
        case notice
        case mcpServers = "mcp_servers"
    }

    public init(
        model: String? = nil,
        modelReasoningEffort: String? = nil,
        projects: [String: CodexProject]? = nil,
        notice: CodexNotice? = nil,
        mcpServers: [String: CodexMCPServer]? = nil
    ) {
        self.model = model
        self.modelReasoningEffort = modelReasoningEffort
        self.projects = projects
        self.notice = notice
        self.mcpServers = mcpServers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.modelReasoningEffort = try container.decodeIfPresent(String.self, forKey: .modelReasoningEffort)
        self.projects = try container.decodeIfPresent([String: CodexProject].self, forKey: .projects)
        self.notice = try container.decodeIfPresent(CodexNotice.self, forKey: .notice)
        self.mcpServers = try container.decodeIfPresent([String: CodexMCPServer].self, forKey: .mcpServers)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(modelReasoningEffort, forKey: .modelReasoningEffort)
        try container.encodeIfPresent(projects, forKey: .projects)
        try container.encodeIfPresent(notice, forKey: .notice)
        try container.encodeIfPresent(mcpServers, forKey: .mcpServers)
    }
}

public struct CodexProject: Codable, Sendable {
    public var trustLevel: String?

    enum CodingKeys: String, CodingKey {
        case trustLevel = "trust_level"
    }

    public init(trustLevel: String? = nil) {
        self.trustLevel = trustLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trustLevel = try container.decodeIfPresent(String.self, forKey: .trustLevel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(trustLevel, forKey: .trustLevel)
    }
}

public struct CodexNotice: Codable, Sendable {
    public var modelMigrations: [String: String]?

    enum CodingKeys: String, CodingKey {
        case modelMigrations = "model_migrations"
    }

    public init(modelMigrations: [String: String]? = nil) {
        self.modelMigrations = modelMigrations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.modelMigrations = try container.decodeIfPresent([String: String].self, forKey: .modelMigrations)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(modelMigrations, forKey: .modelMigrations)
    }
}

public struct CodexMCPServer: Codable, Sendable {
    public var url: String?
    public var command: String?
    public var args: [String]?
    public var env: [String: String]?
    public var enabled: Bool?
    public var enabledTools: [String]?
    public var disabledTools: [String]?
    public var envVars: [String]?
    public var httpHeaders: [String: String]?
    public var envHTTPHeaders: [String: String]?
    public var oauthResource: String?
    public var scopes: [String]?
    public var required: Bool?
    public var startupTimeoutSec: Double?
    public var startupTimeoutMs: Double?
    public var toolTimeoutSec: Double?
    public var type: String?
    public var transport: String?
    public var identity: [String: String]?

    enum CodingKeys: String, CodingKey {
        case url
        case command
        case args
        case env
        case enabled
        case enabledTools = "enabled_tools"
        case disabledTools = "disabled_tools"
        case envVars = "env_vars"
        case httpHeaders = "http_headers"
        case envHTTPHeaders = "env_http_headers"
        case oauthResource = "oauth_resource"
        case scopes
        case required
        case startupTimeoutSec = "startup_timeout_sec"
        case startupTimeoutMs = "startup_timeout_ms"
        case toolTimeoutSec = "tool_timeout_sec"
        case type
        case transport
        case identity
    }

    public init(
        url: String? = nil,
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil,
        enabled: Bool? = nil,
        enabledTools: [String]? = nil,
        disabledTools: [String]? = nil,
        envVars: [String]? = nil,
        httpHeaders: [String: String]? = nil,
        envHTTPHeaders: [String: String]? = nil,
        oauthResource: String? = nil,
        scopes: [String]? = nil,
        required: Bool? = nil,
        startupTimeoutSec: Double? = nil,
        startupTimeoutMs: Double? = nil,
        toolTimeoutSec: Double? = nil,
        type: String? = nil,
        transport: String? = nil,
        identity: [String: String]? = nil
    ) {
        self.url = url
        self.command = command
        self.args = args
        self.env = env
        self.enabled = enabled
        self.enabledTools = enabledTools
        self.disabledTools = disabledTools
        self.envVars = envVars
        self.httpHeaders = httpHeaders
        self.envHTTPHeaders = envHTTPHeaders
        self.oauthResource = oauthResource
        self.scopes = scopes
        self.required = required
        self.startupTimeoutSec = startupTimeoutSec
        self.startupTimeoutMs = startupTimeoutMs
        self.toolTimeoutSec = toolTimeoutSec
        self.type = type
        self.transport = transport
        self.identity = identity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.command = try container.decodeIfPresent(String.self, forKey: .command)
        self.args = try container.decodeIfPresent([String].self, forKey: .args)
        self.env = try container.decodeIfPresent([String: String].self, forKey: .env)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        self.enabledTools = try container.decodeIfPresent([String].self, forKey: .enabledTools)
        self.disabledTools = try container.decodeIfPresent([String].self, forKey: .disabledTools)
        self.envVars = try container.decodeIfPresent([String].self, forKey: .envVars)
        self.httpHeaders = try container.decodeIfPresent([String: String].self, forKey: .httpHeaders)
        self.envHTTPHeaders = try container.decodeIfPresent([String: String].self, forKey: .envHTTPHeaders)
        self.oauthResource = try container.decodeIfPresent(String.self, forKey: .oauthResource)
        self.scopes = try container.decodeIfPresent([String].self, forKey: .scopes)
        self.required = try container.decodeIfPresent(Bool.self, forKey: .required)
        self.startupTimeoutSec = try container.decodeIfPresent(Double.self, forKey: .startupTimeoutSec)
        self.startupTimeoutMs = try container.decodeIfPresent(Double.self, forKey: .startupTimeoutMs)
        self.toolTimeoutSec = try container.decodeIfPresent(Double.self, forKey: .toolTimeoutSec)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.transport = try container.decodeIfPresent(String.self, forKey: .transport)
        self.identity = try container.decodeIfPresent([String: String].self, forKey: .identity)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(enabledTools, forKey: .enabledTools)
        try container.encodeIfPresent(disabledTools, forKey: .disabledTools)
        try container.encodeIfPresent(envVars, forKey: .envVars)
        try container.encodeIfPresent(httpHeaders, forKey: .httpHeaders)
        try container.encodeIfPresent(envHTTPHeaders, forKey: .envHTTPHeaders)
        try container.encodeIfPresent(oauthResource, forKey: .oauthResource)
        try container.encodeIfPresent(scopes, forKey: .scopes)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(startupTimeoutSec, forKey: .startupTimeoutSec)
        try container.encodeIfPresent(startupTimeoutMs, forKey: .startupTimeoutMs)
        try container.encodeIfPresent(toolTimeoutSec, forKey: .toolTimeoutSec)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(transport, forKey: .transport)
        try container.encodeIfPresent(identity, forKey: .identity)
    }
}

public extension CodexMCPServer {
    init(mcp: MCP) {
        let dict = mcp.json.value as? [String: Any] ?? [:]
        self.url = dict["url"] as? String
        self.command = dict["command"] as? String
        self.args = dict["args"] as? [String]
        self.env = dict["env"] as? [String: String]
        self.enabled = dict["enabled"] as? Bool
        self.enabledTools = dict["enabled_tools"] as? [String]
        self.disabledTools = dict["disabled_tools"] as? [String]
        self.envVars = dict["env_vars"] as? [String]
        self.httpHeaders = dict["http_headers"] as? [String: String]
        self.envHTTPHeaders = dict["env_http_headers"] as? [String: String]
        self.oauthResource = dict["oauth_resource"] as? String
        self.scopes = dict["scopes"] as? [String]
        self.required = dict["required"] as? Bool
        self.startupTimeoutSec = dict["startup_timeout_sec"] as? Double
        self.startupTimeoutMs = dict["startup_timeout_ms"] as? Double
        self.toolTimeoutSec = dict["tool_timeout_sec"] as? Double
        self.type = dict["type"] as? String
        self.transport = dict["transport"] as? String
        self.identity = dict["identity"] as? [String: String]
    }
}
