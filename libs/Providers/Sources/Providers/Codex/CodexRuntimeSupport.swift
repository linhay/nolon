import Foundation
import CodexCLIKit
import CodexAppServerKit

enum CodexRuntimeSupport {
    static func resolvedBinary(
        preferredBinary: String?,
        environment: [String: String]
    ) -> String {
        let candidate = (preferredBinary?.isEmpty == false) ? preferredBinary! : "codex"
        if let resolved = CodexCommandExecutor(executable: candidate, environment: environment).resolveExecutable() {
            return resolved
        }

        return candidate
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
