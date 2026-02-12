import Foundation
import CodexCLIKit
import CodexAppServerKit

enum CodexRuntimeSupport {
    static func resolvedBinary(
        preferredBinary: String?,
        environment: [String: String]
    ) -> String {
        if let preferredBinary, !preferredBinary.isEmpty {
            return preferredBinary
        }

        if let resolved = CodexCommandExecutor(executable: "codex", environment: environment).resolveExecutable() {
            return resolved
        }

        return "codex"
    }

    static func withRuntimeService<T>(
        preferredBinary: String?,
        environment: [String: String],
        clientName: String = "codexhelper",
        clientVersion: String = "1.0.0",
        operation: @Sendable (CodexAccountRuntimeService) async throws -> T
    ) async throws -> T {
        let service = CodexAccountRuntimeService(
            executable: resolvedBinary(preferredBinary: preferredBinary, environment: environment),
            environment: environment
        )
        defer { Task { await service.shutdown() } }
        try await service.initialize(clientName: clientName, clientVersion: clientVersion)
        return try await operation(service)
    }
}
