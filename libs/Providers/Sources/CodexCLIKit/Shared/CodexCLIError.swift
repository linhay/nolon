import Foundation

public enum CodexCLIError: LocalizedError, Sendable, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
    case nonZeroExit(command: [String], code: Int32, stderr: String)
    case timedOut(seconds: TimeInterval)
    case invalidOutput(String)
    case protocolError(String)
    case recoverableFallback(String)

    public var errorDescription: String? {
        switch self {
        case let .executableNotFound(name):
            return "Codex executable not found: \(name)"
        case let .launchFailed(message):
            return "Failed to launch codex: \(message)"
        case let .nonZeroExit(command, code, stderr):
            let rendered = command.joined(separator: " ")
            return "Codex command failed (\(code)): \(rendered)\n\(stderr)"
        case let .timedOut(seconds):
            return "Codex command timed out after \(Int(seconds))s"
        case let .invalidOutput(message):
            return "Invalid codex output: \(message)"
        case let .protocolError(message):
            return "Codex protocol error: \(message)"
        case let .recoverableFallback(message):
            return "Codex runtime path failed but is recoverable: \(message)"
        }
    }

    public var isRecoverableByFileFallback: Bool {
        switch self {
        case .recoverableFallback:
            return true
        default:
            return false
        }
    }
}

public struct CodexExecutionResult: Sendable, Equatable {
    public let command: [String]
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let duration: TimeInterval

    public init(command: [String], stdout: String, stderr: String, exitCode: Int32, duration: TimeInterval) {
        self.command = command
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.duration = duration
    }
}

public struct CodexVersion: Sendable, Equatable {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }
}
