import Foundation
import CodexCLIKit
import ProvidersShared
import SKProcessRunner

/// Runs `codex` inside a PTY, sends `/status`, captures text, and parses credits/limits.
public struct CodexStatusProbe {
    public var codexBinary: String = "codex"
    public var timeout: TimeInterval = 18.0
    public var keepCLISessionsAlive: Bool = false
    public var environment: [String: String] = ProcessInfo.processInfo.environment
    private let runner: any CodexCLICommandRunning
    private let fallbackRunner: any CodexCLICommandRunning

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runner: (any CodexCLICommandRunning)? = nil,
        fallbackRunner: any CodexCLICommandRunning = TTYCommandRunner()
    ) {
        self.environment = environment
        self.runner = runner ?? Self.defaultRunner()
        self.fallbackRunner = fallbackRunner
    }

    public init(
        codexBinary: String = "codex",
        timeout: TimeInterval = 18.0,
        keepCLISessionsAlive: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runner: (any CodexCLICommandRunning)? = nil,
        fallbackRunner: any CodexCLICommandRunning = TTYCommandRunner()
    ) {
        self.codexBinary = codexBinary
        self.timeout = timeout
        self.keepCLISessionsAlive = keepCLISessionsAlive
        self.environment = environment
        self.runner = runner ?? Self.defaultRunner()
        self.fallbackRunner = fallbackRunner
    }

    public func fetch() async throws -> CodexStatusSnapshot {
        let resolved: String
        do {
            resolved = try await CodexCommandExecutor(
                executable: self.codexBinary,
                environment: self.environment
            ).requireResolvedExecutableAsync()
        } catch CodexCLIError.executableNotFound {
            throw CodexStatusProbeError.codexNotInstalled
        }

        do {
            return try await self.runAndParse(binary: resolved, rows: 60, cols: 200, timeout: self.timeout)
        } catch let error as CodexStatusProbeError {
            switch error {
            case .parseFailed, .timedOut:
                return try await self.runAndParse(
                    binary: resolved,
                    rows: 70,
                    cols: 220,
                    timeout: max(self.timeout, 24.0))
            default:
                throw error
            }
        }
    }

    public static func parse(text: String) throws -> CodexStatusSnapshot {
        let clean = TextParsing.stripANSICodes(text)
        guard !clean.isEmpty else { throw CodexStatusProbeError.timedOut }
        if clean.localizedCaseInsensitiveContains("data not available yet") {
            throw CodexStatusProbeError.parseFailed("data not available yet")
        }
        if self.containsUpdatePrompt(clean) {
            throw CodexStatusProbeError.updateRequired(
                "Run `bun install -g @openai/codex` to continue (update prompt blocking /status).")
        }
        let credits = TextParsing.firstNumber(pattern: #"Credits:\s*([0-9][0-9.,]*)"#, text: clean)
        let fiveLine = TextParsing.firstLine(matching: #"5h limit[^\n]*"#, text: clean)
        let weekLine = TextParsing.firstLine(matching: #"Weekly limit[^\n]*"#, text: clean)
        let fivePct = fiveLine.flatMap(TextParsing.percentLeft(fromLine:))
        let weekPct = weekLine.flatMap(TextParsing.percentLeft(fromLine:))
        let fiveReset = fiveLine.flatMap(TextParsing.resetString(fromLine:))
        let weekReset = weekLine.flatMap(TextParsing.resetString(fromLine:))
        if credits == nil, fivePct == nil, weekPct == nil {
            if text.contains("\u{001B}") {
                return CodexStatusSnapshot(
                    credits: nil,
                    fiveHourPercentLeft: nil,
                    weeklyPercentLeft: nil,
                    fiveHourResetDescription: nil,
                    weeklyResetDescription: nil,
                    rawText: clean)
            }
            throw CodexStatusProbeError.parseFailed(clean.prefix(400).description)
        }
        return CodexStatusSnapshot(
            credits: credits,
            fiveHourPercentLeft: fivePct,
            weeklyPercentLeft: weekPct,
            fiveHourResetDescription: fiveReset,
            weeklyResetDescription: weekReset,
            rawText: clean)
    }

    private func runAndParse(binary: String, rows: UInt16, cols: UInt16, timeout: TimeInterval) async throws -> CodexStatusSnapshot {
        let script = "/status\n"
        do {
            let result = try await runner.run(
                binary: binary,
                send: script,
                options: .init(
                    rows: rows,
                    cols: cols,
                    timeout: timeout,
                    extraArgs: ["-s", "read-only", "-a", "untrusted"]))
            return try Self.parse(text: result.text)
        } catch let error as TTYCommandRunner.Error {
            switch error {
            case .timedOut:
                throw CodexStatusProbeError.timedOut
            case .binaryNotFound:
                throw CodexStatusProbeError.codexNotInstalled
            case let .launchFailed(message):
                throw CodexStatusProbeError.parseFailed(message)
            }
        }
    }

    private static func containsUpdatePrompt(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("update available") && lower.contains("codex")
    }

    private static func defaultRunner() -> any CodexCLICommandRunning {
#if canImport(SKProcessRunner)
        return SKProcessRunnerCommandRunner()
#else
        return TTYCommandRunner()
#endif
    }
}
