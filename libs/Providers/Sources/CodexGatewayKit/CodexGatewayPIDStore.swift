import Foundation
import ProviderUsage
import STFilePath

public protocol CodexGatewayPIDStoring: Sendable {
    func load() async -> Int32?
    func save(_ pid: Int32) async throws
    func clear() async throws
}

public actor CodexGatewayPIDStore: CodexGatewayPIDStoring {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.init(file: authManager.nolonCodexRootFolder().folder("gateway").file("gateway.pid"))
    }

    public func load() async -> Int32? {
        guard let raw = try? file.read().trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(raw)
        else {
            return nil
        }
        return pid
    }

    public func save(_ pid: Int32) async throws {
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: "\(pid)\n")
    }

    public func clear() async throws {
        guard file.isExists else { return }
        try? FileManager.default.removeItem(at: file.url)
    }
}
