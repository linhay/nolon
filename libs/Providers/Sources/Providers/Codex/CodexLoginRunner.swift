import Foundation
import CodexCLIKit
import SKProcessRunner
import STFilePath

public enum CodexLoginError: LocalizedError, Sendable, Equatable {
    case binaryNotFound(String)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .binaryNotFound(bin):
            "Missing CLI '\(bin)'. Install it (e.g. npm i -g @openai/codex) or add it to PATH."
        case let .launchFailed(msg):
            "Failed to launch Codex login: \(msg)"
        }
    }
}

public final class CodexLoginHandle: @unchecked Sendable {
    private let process: Process

    init(process: Process) {
        self.process = process
    }

    public var isRunning: Bool {
        process.isRunning
    }

    public func cancel() {
        if process.isRunning {
            process.terminate()
        }
    }
}

public struct CodexLoginRunner: Sendable {
    public init() {}

    public func startLogin(
        binary: String = "codex",
        environment: [String: String],
        codexHome: URL
    ) throws -> CodexLoginHandle {
        try startLogin(binary: binary, environment: environment, codexHome: STFolder(codexHome))
    }

    public func startLogin(
        binary: String = "codex",
        environment: [String: String],
        codexHome: STFolder
    ) throws -> CodexLoginHandle {
        let env = Self.mergedEnvironment(environment: environment, codexHome: codexHome)
        let resolver = CodexCommandExecutor(executable: binary, environment: env)
        guard let resolved = resolver.resolveExecutable() else {
            throw CodexLoginError.binaryNotFound(binary)
        }

        let process = Process()
        process.executableURL = STFile(resolved).url
        process.arguments = ["login"]
        process.environment = env
        process.standardInput = nil
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
        } catch {
            throw CodexLoginError.launchFailed(error.localizedDescription)
        }

        return CodexLoginHandle(process: process)
    }

    private static func mergedEnvironment(environment: [String: String], codexHome: STFolder) -> [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        let shellEnv = SKProcessRunner.loadUserShellEnvironmentSync(environment: processEnv)
        var env = processEnv.merging(shellEnv, uniquingKeysWith: { _, shell in shell })
        env.merge(environment) { _, new in new }
        if env["PATH"]?.isEmpty != false,
           let shellPATH = SKProcessRunner.loadUserShellPATHSync(environment: processEnv) {
            env["PATH"] = shellPATH
        }
        env["CODEX_HOME"] = codexHome.url.path
        return env
    }
}
