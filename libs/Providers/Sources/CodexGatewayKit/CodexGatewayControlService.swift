import Foundation
import ProviderUsage
import STFilePath

public protocol CodexGatewayStatusStoring: Sendable {
    func load() async -> CodexGatewayStatusSnapshot?
    func save(_ snapshot: CodexGatewayStatusSnapshot) async throws
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
