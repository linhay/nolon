#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

/// Executes an interactive CLI inside a pseudo-terminal and returns all captured text.
public struct TTYCommandRunner: Sendable {
    public struct Result: Sendable {
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    public struct Options: Sendable {
        public var rows: UInt16 = 50
        public var cols: UInt16 = 160
        public var timeout: TimeInterval = 20.0
        public var idleTimeout: TimeInterval?
        public var workingDirectory: URL?
        public var extraArgs: [String] = []
        public var initialDelay: TimeInterval = 0.4
        public var sendEnterEvery: TimeInterval?
        public var sendOnSubstrings: [String: String]
        public var stopOnURL: Bool
        public var stopOnSubstrings: [String]
        public var settleAfterStop: TimeInterval

        public init(
            rows: UInt16 = 50,
            cols: UInt16 = 160,
            timeout: TimeInterval = 20.0,
            idleTimeout: TimeInterval? = nil,
            workingDirectory: URL? = nil,
            extraArgs: [String] = [],
            initialDelay: TimeInterval = 0.4,
            sendEnterEvery: TimeInterval? = nil,
            sendOnSubstrings: [String: String] = [:],
            stopOnURL: Bool = false,
            stopOnSubstrings: [String] = [],
            settleAfterStop: TimeInterval = 0.25)
        {
            self.rows = rows
            self.cols = cols
            self.timeout = timeout
            self.idleTimeout = idleTimeout
            self.workingDirectory = workingDirectory
            self.extraArgs = extraArgs
            self.initialDelay = initialDelay
            self.sendEnterEvery = sendEnterEvery
            self.sendOnSubstrings = sendOnSubstrings
            self.stopOnURL = stopOnURL
            self.stopOnSubstrings = stopOnSubstrings
            self.settleAfterStop = settleAfterStop
        }
    }

    public enum Error: Swift.Error, LocalizedError, Sendable, Equatable {
        case binaryNotFound(String)
        case launchFailed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case let .binaryNotFound(bin):
                "Missing CLI '\(bin)'. Install it (e.g. npm i -g @openai/codex) or add it to PATH."
            case let .launchFailed(msg): "Failed to launch process: \(msg)"
            case .timedOut: "PTY command timed out."
            }
        }
    }

    public init() {}

    public static func which(
        _ command: String,
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> String?
    {
        if command.contains("/") {
            return FileManager.default.isExecutableFile(atPath: command) ? command : nil
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.environment = env

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func run(binary: String, send: String, options: Options = Options()) throws -> Result {
        let resolvedBinary: String
        if let located = Self.which(binary) {
            resolvedBinary = located
        } else {
            throw Error.binaryNotFound(binary)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedBinary)
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = env["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        process.environment = env
        
        process.arguments = options.extraArgs
        
        if let cwd = options.workingDirectory {
            process.currentDirectoryURL = cwd
        }
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe
        
        do {
            try process.run()
        } catch {
            throw Error.launchFailed(error.localizedDescription)
        }
        
        // Send input
        if !send.isEmpty, let data = send.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        if !send.isEmpty {
            stdinPipe.fileHandleForWriting.closeFile()
        }
        
        final class OutputBuffer: @unchecked Sendable {
            private let lock = NSLock()
            private var text = ""

            func append(_ chunk: String) {
                self.lock.lock()
                self.text += chunk
                self.lock.unlock()
            }

            func snapshot() -> String {
                self.lock.lock()
                let out = self.text
                self.lock.unlock()
                return out
            }
        }

        let buffer = OutputBuffer()

        let appendText: @Sendable (Data) -> Void = { data in
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            buffer.append(text)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            appendText(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            appendText(handle.availableData)
        }

        // Wait with timeout
        let startTime = Date()

        while process.isRunning && Date().timeIntervalSince(startTime) < options.timeout {
            if !options.stopOnSubstrings.isEmpty {
                let snapshot = buffer.snapshot()

                for substring in options.stopOnSubstrings where snapshot.contains(substring) {
                    Thread.sleep(forTimeInterval: options.settleAfterStop)
                    process.terminate()
                    break
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if process.isRunning {
            process.terminate()
            throw Error.timedOut
        }

        // Drain anything left after removing handlers.
        appendText(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        appendText(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        return Result(text: buffer.snapshot())
    }
}

extension TTYCommandRunner {
    public func run(binary: String, send: String, options: Options = Options()) async throws -> Result {
        try await Task.detached(priority: .utility) {
            try self.run(binary: binary, send: send, options: options)
        }.value
    }
}
