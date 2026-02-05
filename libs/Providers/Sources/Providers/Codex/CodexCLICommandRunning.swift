import Foundation
import ProvidersShared

public protocol CodexCLICommandRunning: Sendable {
    func run(binary: String, send: String, options: TTYCommandRunner.Options) async throws -> TTYCommandRunner.Result
}

extension TTYCommandRunner: CodexCLICommandRunning {}
