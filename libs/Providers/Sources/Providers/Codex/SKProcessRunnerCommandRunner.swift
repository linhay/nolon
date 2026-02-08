#if canImport(SKProcessRunner)
import Foundation
import ProvidersShared
import SKProcessRunner

public struct SKProcessRunnerCommandRunner: CodexCLICommandRunning {
    public init() {}

    public func run(
        binary: String,
        send: String,
        options: TTYCommandRunner.Options
    ) async throws -> TTYCommandRunner.Result {
        let env = Self.mergedEnvironment(options: options)
        let payload = SKProcessPayload(
            executable: .path(binary),
            arguments: options.extraArgs,
            stdinData: send.isEmpty ? nil : Data(send.utf8),
            cwd: options.workingDirectory,
            environment: SKProcessEnvironment(env),
            timeoutMs: Int(max(1.0, options.timeout) * 1000.0),
            throwOnNonZeroExit: false
        )

        let exeURL: URL
        do {
            exeURL = try SKProcessRunner.resolveExecutable(binary, environment: env)
        } catch let error as SKProcessRunError {
            switch error {
            case let .executableNotFound(name):
                throw TTYCommandRunner.Error.binaryNotFound(name)
            case let .invalidExecutable(value):
                throw TTYCommandRunner.Error.launchFailed("Invalid executable: \(value)")
            default:
                throw TTYCommandRunner.Error.launchFailed(error.localizedDescription)
            }
        } catch {
            throw TTYCommandRunner.Error.launchFailed(error.localizedDescription)
        }

        var payload = SKProcessPayload.executableURL(exeURL)
        payload.arguments = options.extraArgs
        payload.stdinData = send.isEmpty ? nil : Data(send.utf8)
        payload.cwd = options.workingDirectory
        payload.environment = SKProcessEnvironment(env)
        payload.timeoutMs = Int(max(1.0, options.timeout) * 1000.0)
        payload.throwOnNonZeroExit = false

        do {
            let result = try await SKProcessRunner.run(payload)

            let text = Self.combine(stdout: result.stdout, stderr: result.stderr)
            return TTYCommandRunner.Result(text: text)
        } catch let error as SKProcessRunError {
            switch error {
            case let .timedOut(_, stdoutData, stderrData, truncated: _):
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                let _ = Self.combine(stdout: stdout, stderr: stderr)
                throw TTYCommandRunner.Error.timedOut
            default:
                throw TTYCommandRunner.Error.launchFailed(error.localizedDescription)
            }
        } catch {
            throw TTYCommandRunner.Error.launchFailed(error.localizedDescription)
        }
    }

    private static func mergedEnvironment(options: TTYCommandRunner.Options) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if env["PATH"] == nil || env["PATH"]?.isEmpty == true {
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin"
        }
        return env
    }

    private static func combine(stdout: String, stderr: String) -> String {
        if stdout.isEmpty { return stderr }
        if stderr.isEmpty { return stdout }
        return stdout + "\n" + stderr
    }
}
#endif
