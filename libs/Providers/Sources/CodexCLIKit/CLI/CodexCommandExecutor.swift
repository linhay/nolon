import Foundation
import SKProcessRunner
import STFilePath

public struct CodexCommandExecutor: Sendable {
    private let executable: String
    private let environment: [String: String]

    public init(executable: String = "codex", environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.executable = executable
        self.environment = environment
    }

    public static func codexHomeDirectoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        codexHomeDirectory(environment: environment).url
    }

    public static func codexHomeDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> STFolder {
        if let override = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty
        {
            return STFolder(override)
        }

        return STFolder(NSHomeDirectory()).folder(".codex")
    }

    public static func codexHomeDirectoryPath(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        codexHomeDirectoryURL(environment: environment).path
    }

    public func resolveExecutable() -> String? {
        if executable.contains("/") {
            return Self.isExecutable(path: executable) ? executable : nil
        }

        if let override = environment["CODEX_CLI_PATH"], Self.isExecutable(path: override) {
            return override
        }

        if let url = SKProcessRunner.resolveExecutableInPath(named: executable, environment: environment) {
            return url.path
        }

        if let url = SKProcessRunner.resolveExecutableInUserShellSync(named: executable, environment: environment) {
            return url.path
        }

        for candidate in Self.fallbackExecutablePaths(for: executable) {
            if Self.isExecutable(path: candidate) {
                return candidate
            }
        }

        return nil
    }

    public func resolveExecutableAsync() async -> String? {
        if executable.contains("/") {
            return Self.isExecutable(path: executable) ? executable : nil
        }

        if let override = environment["CODEX_CLI_PATH"], Self.isExecutable(path: override) {
            return override
        }

        if let url = SKProcessRunner.resolveExecutableInPath(named: executable, environment: environment) {
            return url.path
        }

        if let url = await SKProcessRunner.resolveExecutableInUserShell(named: executable, environment: environment) {
            return url.path
        }

        for candidate in Self.fallbackExecutablePaths(for: executable) {
            if Self.isExecutable(path: candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func fallbackExecutablePaths(for executable: String) -> [String] {
        [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "\(NSHomeDirectory())/.bun/bin/\(executable)",
            "\(NSHomeDirectory())/.npm-global/bin/\(executable)",
        ]
    }

    private static func isExecutable(path: String) -> Bool {
        let file = STFile(path)
        guard file.isExists else { return false }
        return file.permission.contains(.executable)
    }

    public func requireResolvedExecutable() throws -> String {
        guard let resolved = resolveExecutable() else {
            throw CodexCLIError.executableNotFound(executable)
        }
        return resolved
    }

    public func requireResolvedExecutableAsync() async throws -> String {
        guard let resolved = await resolveExecutableAsync() else {
            throw CodexCLIError.executableNotFound(executable)
        }
        return resolved
    }

    public func readVersion() throws -> CodexVersion {
        let result = try executeSync(args: ["--version"], timeout: 10)
        let line = result.stdout.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return CodexVersion(raw: line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func execute(args: [String], timeout: TimeInterval = 60) async throws -> CodexExecutionResult {
        let resolved = try requireResolvedExecutable()
        let startedAt = Date()

        var payload = SKProcessPayload.executableURL(STFile(resolved).url)
        payload.arguments = args
        payload.environment = SKProcessEnvironment(environment)
        payload.timeoutMs = Int(max(1.0, timeout) * 1000.0)
        payload.throwOnNonZeroExit = false

        do {
            let result = try await SKProcessRunner.run(payload)
            let elapsed = Date().timeIntervalSince(startedAt)
            let stdout = result.stdout
            let stderr = result.stderr
            let exitCode = Int32(result.exitCode)
            if result.exitCode != 0 {
                throw CodexCLIError.nonZeroExit(command: [resolved] + args, code: exitCode, stderr: stderr)
            }
            return CodexExecutionResult(
                command: [resolved] + args,
                stdout: stdout,
                stderr: stderr,
                exitCode: exitCode,
                duration: elapsed
            )
        } catch let error as SKProcessRunError {
            switch error {
            case .timedOut:
                throw CodexCLIError.timedOut(seconds: timeout)
            default:
                throw CodexCLIError.launchFailed(error.localizedDescription)
            }
        } catch let error as CodexCLIError {
            throw error
        } catch {
            throw CodexCLIError.launchFailed(error.localizedDescription)
        }
    }

    private func executeSync(args: [String], timeout: TimeInterval = 30) throws -> CodexExecutionResult {
        let resolved = try requireResolvedExecutable()
        let startedAt = Date()
        var payload = SKProcessPayload.executableURL(STFile(resolved).url)
        payload.arguments = args
        payload.environment = SKProcessEnvironment(environment)
        payload.timeoutMs = Int(max(1, timeout) * 1000.0)
        payload.throwOnNonZeroExit = false

        let result: SKProcessResult
        do {
            result = try SKProcessRunner.runSync(payload)
        } catch let error as SKProcessRunError {
            switch error {
            case .timedOut:
                throw CodexCLIError.timedOut(seconds: timeout)
            default:
                throw CodexCLIError.launchFailed(error.localizedDescription)
            }
        } catch {
            throw CodexCLIError.launchFailed(error.localizedDescription)
        }

        let stdout = result.stdout
        let stderr = result.stderr
        let exitCode = Int32(result.exitCode)

        if exitCode != 0 {
            throw CodexCLIError.nonZeroExit(command: [resolved] + args, code: exitCode, stderr: stderr)
        }

        return CodexExecutionResult(
            command: [resolved] + args,
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            duration: Date().timeIntervalSince(startedAt)
        )
    }
}

public struct CodexHelpNode: Sendable, Equatable {
    public let path: [String]
    public let commands: Set<String>
    public let options: Set<String>

    public init(path: [String], commands: Set<String>, options: Set<String>) {
        self.path = path
        self.commands = commands
        self.options = options
    }
}

public struct CodexHelpScanner: Sendable {
    private let executor: CodexCommandExecutor

    public init(executor: CodexCommandExecutor) {
        self.executor = executor
    }

    public func scanTopLevel() async throws -> CodexHelpNode {
        let result = try await executor.execute(args: ["--help"], timeout: 20)
        return Self.parseHelp(path: [], text: result.stdout)
    }

    public func scan(commandPath: [String]) async throws -> CodexHelpNode {
        let result = try await executor.execute(args: commandPath + ["--help"], timeout: 20)
        return Self.parseHelp(path: commandPath, text: result.stdout)
    }

    static func parseHelp(path: [String], text: String) -> CodexHelpNode {
        var commands = Set<String>()
        var options = Set<String>()

        var inCommands = false
        let commandPattern = #"^\s{2}([a-z][a-z0-9-]*)\s{2,}"#
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Commands:" {
                inCommands = true
                continue
            }
            if trimmed == "Options:" || trimmed == "Arguments:" {
                inCommands = false
                continue
            }
            if inCommands {
                if let range = line.range(of: commandPattern, options: .regularExpression) {
                    let matched = String(line[range])
                    let token = matched.trimmingCharacters(in: .whitespaces).split(whereSeparator: \.isWhitespace).first.map(String.init)
                    if let token, token != "help" {
                        commands.insert(token)
                    }
                }
                continue
            }
            if trimmed.hasPrefix("-") {
                let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                for token in tokens where token.hasPrefix("-") {
                    options.insert(token.replacingOccurrences(of: ",", with: ""))
                }
            }
        }

        return CodexHelpNode(path: path, commands: commands, options: options)
    }
}
