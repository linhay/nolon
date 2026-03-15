import Foundation
import ProviderUsage
import STFilePath

public protocol CodexGatewayStatusStoring: Sendable {
    func load() async -> CodexGatewayStatusSnapshot?
    func save(_ snapshot: CodexGatewayStatusSnapshot) async throws
}

public struct CodexGatewayVirtualAccountState: Sendable, Equatable, Codable {
    public let providerID: String
    public let previousActiveAccountID: UUID?
    public let virtualAccountID: UUID

    public init(providerID: String, previousActiveAccountID: UUID?, virtualAccountID: UUID) {
        self.providerID = providerID
        self.previousActiveAccountID = previousActiveAccountID
        self.virtualAccountID = virtualAccountID
    }
}

public protocol CodexGatewayVirtualAccountStateStoring: Sendable {
    func load(providerID: String) async -> CodexGatewayVirtualAccountState?
    func save(_ state: CodexGatewayVirtualAccountState) async throws
    func remove(providerID: String) async throws
}

public actor CodexGatewayVirtualAccountStateStore: CodexGatewayVirtualAccountStateStoring {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.init(file: authManager.nolonCodexRootFolder().folder("gateway").file("virtual-account.json"))
    }

    public func load(providerID: String) async -> CodexGatewayVirtualAccountState? {
        loadAll()[providerID]
    }

    public func save(_ state: CodexGatewayVirtualAccountState) async throws {
        var states = loadAll()
        states[state.providerID] = state
        try persist(states)
    }

    public func remove(providerID: String) async throws {
        var states = loadAll()
        states.removeValue(forKey: providerID)
        try persist(states)
    }

    private func loadAll() -> [String: CodexGatewayVirtualAccountState] {
        guard let data = try? file.data(),
              !data.isEmpty
        else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: CodexGatewayVirtualAccountState].self, from: data)) ?? [:]
    }

    private func persist(_ states: [String: CodexGatewayVirtualAccountState]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(states)
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: data)
    }
}

public actor CodexGatewayStateStore: CodexGatewayStatusStoring {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.init(file: authManager.nolonCodexRootFolder().folder("gateway").file("state.json"))
    }

    public func load() async -> CodexGatewayStatusSnapshot? {
        guard let data = try? file.data(),
              !data.isEmpty
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CodexGatewayStatusSnapshot.self, from: data)
    }

    public func save(_ snapshot: CodexGatewayStatusSnapshot) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: data)
    }
}

public actor CodexGatewayControlService {
    private let statusStore: any CodexGatewayStatusStoring
    private let now: @Sendable () -> Date

    public init(
        statusStore: any CodexGatewayStatusStoring = CodexGatewayStateStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.statusStore = statusStore
        self.now = now
    }

    public func status(config: CodexGatewayConfig = CodexGatewayConfig()) async -> CodexGatewayStatusSnapshot {
        await statusStore.load() ?? CodexGatewayStatusSnapshot(
            status: .stopped,
            host: config.host,
            port: config.port,
            startedAt: nil
        )
    }

    @discardableResult
    public func start(config: CodexGatewayConfig) async throws -> CodexGatewayStatusSnapshot {
        let snapshot = CodexGatewayStatusSnapshot(
            status: .running,
            host: config.host,
            port: config.port,
            startedAt: now()
        )
        try await statusStore.save(snapshot)
        return snapshot
    }

    @discardableResult
    public func stop(config: CodexGatewayConfig = CodexGatewayConfig()) async throws -> CodexGatewayStatusSnapshot {
        let current = await statusStore.load()
        let snapshot = CodexGatewayStatusSnapshot(
            status: .stopped,
            host: current?.host ?? config.host,
            port: current?.port ?? config.port,
            startedAt: nil
        )
        try await statusStore.save(snapshot)
        return snapshot
    }
}
