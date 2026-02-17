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

    enum CodingKeys: String, CodingKey {
        case url
        case command
        case args
        case env
        case enabled
    }

    public init(
        url: String? = nil,
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil,
        enabled: Bool? = nil
    ) {
        self.url = url
        self.command = command
        self.args = args
        self.env = env
        self.enabled = enabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.command = try container.decodeIfPresent(String.self, forKey: .command)
        self.args = try container.decodeIfPresent([String].self, forKey: .args)
        self.env = try container.decodeIfPresent([String: String].self, forKey: .env)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(enabled, forKey: .enabled)
    }
}
