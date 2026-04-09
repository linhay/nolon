import Foundation
import SKProcessRunner
import STFilePath
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct NolonRuntimeProcessSnapshot: Sendable, Equatable {
    let pid: Int32
    let ppid: Int32?
    let elapsed: String
    let command: String
    let workingDirectory: String?

    init(
        pid: Int32,
        ppid: Int32?,
        elapsed: String,
        command: String,
        workingDirectory: String? = nil
    ) {
        self.pid = pid
        self.ppid = ppid
        self.elapsed = elapsed
        self.command = command
        self.workingDirectory = workingDirectory
    }
}

protocol NolonCodexRuntimeProcessInspecting: Sendable {
    func listProcesses() throws -> [NolonRuntimeProcessSnapshot]
}

protocol NolonCodexRuntimeSignalControlling: Sendable {
    func send(signal: Int32, to pid: Int32) throws
    func isRunning(pid: Int32) -> Bool
}

struct NolonCodexRuntimeProcessInspector: NolonCodexRuntimeProcessInspecting {
    func listProcesses() throws -> [NolonRuntimeProcessSnapshot] {
        var payload = SKProcessPayload.executableURL(STPath("/bin/ps").url)
        payload.arguments = ["-axo", "pid=,ppid=,etime=,command="]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        let result = try SKProcessRunner.runSync(payload)

        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let stdout = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let message = stderr.isEmpty ? (stdout.isEmpty ? "ps command failed" : stdout) : stderr
            throw NolonCoreCLIError.domainFailed(code: "runtime_ps_failed", message: message)
        }
        let content = result.stdout

        return content
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
                guard parts.count >= 4, let pid = Int32(parts[0]), let ppid = Int32(parts[1]) else {
                    return nil
                }
                let elapsed = String(parts[2])
                let command = parts.dropFirst(3).joined(separator: " ")
                return NolonRuntimeProcessSnapshot(
                    pid: pid,
                    ppid: ppid,
                    elapsed: elapsed,
                    command: command,
                    workingDirectory: workingDirectory(of: pid)
                )
            }
    }

    private func workingDirectory(of pid: Int32) -> String? {
        var payload = SKProcessPayload.executableURL(STPath("/usr/sbin/lsof").url)
        payload.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 2_000

        guard let result = try? SKProcessRunner.runSync(payload), result.exitCode == 0 else {
            return nil
        }

        let lines = result.stdout.split(separator: "\n")
        for line in lines where line.hasPrefix("n") {
            let path = String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                return path
            }
        }
        return nil
    }
}

struct NolonCodexRuntimeSignalController: NolonCodexRuntimeSignalControlling {
    func send(signal: Int32, to pid: Int32) throws {
        if kill(pid, signal) != 0 {
            let code = errno
            throw NolonCoreCLIError.domainFailed(
                code: "runtime_signal_failed",
                message: "Failed to send signal \(signal) to pid \(pid), errno=\(code)"
            )
        }
    }

    func isRunning(pid: Int32) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}
