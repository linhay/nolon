import XCTest
import SKProcessRunner
@testable import nolon

@MainActor
final class XcodeMCPKitRuntimeServiceTests: XCTestCase {
    func testStartWhenBinaryMissingSetsFailed() async {
        let service = XcodeMCPKitRuntimeService(
            executableResolver: { nil }
        )

        await service.start()

        if case let .failed(message) = service.state {
            XCTAssertTrue(message.contains("xcodemcpkit"))
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testStartAndStopTransitionsToIdle() async {
        let session = MockRuntimeSession(
            pid: 7788,
            waitResult: .success(
                SKProcessResult(
                    stdoutData: Data(),
                    stderrData: Data(),
                    exitCode: 0,
                    timedOut: false,
                    truncated: false
                )
            )
        )
        let service = XcodeMCPKitRuntimeService(
            executableResolver: { URL(fileURLWithPath: "/tmp/xcodemcpkit") },
            sessionFactory: { _ in session },
            stopTimeoutNanoseconds: 500_000_000
        )

        await service.start()
        if case let .running(pid, _) = service.state {
            XCTAssertEqual(pid, 7788)
        } else {
            XCTFail("Expected running state")
        }

        await service.stop(force: false)
        if case .idle = service.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected idle after stop")
        }
        let terminated = await session.terminateCallCount
        XCTAssertEqual(terminated, 1)
    }

    func testStartWhenSessionExitsNonZeroSetsFailed() async {
        let stderr = Data("boom".utf8)
        let session = MockRuntimeSession(
            pid: 8899,
            waitResult: .failure(SKProcessRunError.nonZeroExit(exitCode: 9, stdoutData: Data(), stderrData: stderr))
        )
        let service = XcodeMCPKitRuntimeService(
            executableResolver: { URL(fileURLWithPath: "/tmp/xcodemcpkit") },
            sessionFactory: { _ in session }
        )

        await service.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        if case let .failed(message) = service.state {
            XCTAssertTrue(message.contains("boom"))
        } else {
            XCTFail("Expected failed state after non-zero exit")
        }
    }

    func testStartWhenSessionExitsWithCodeNineAndNoStderr_TreatsAsIdle() async {
        let session = MockRuntimeSession(
            pid: 8898,
            waitResult: .failure(SKProcessRunError.nonZeroExit(exitCode: 9, stdoutData: Data(), stderrData: Data())),
            stdoutChunks: [Data("before kill line\n".utf8)]
        )
        let service = XcodeMCPKitRuntimeService(
            executableResolver: { URL(fileURLWithPath: "/tmp/xcodemcpkit") },
            sessionFactory: { _ in session }
        )

        await service.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        if case .idle = service.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected idle state for exit 9 with empty stderr, got \(service.state)")
        }
        XCTAssertTrue(service.logsText.contains("pre-kill output snapshot begin"))
        XCTAssertTrue(service.logsText.contains("before kill line"))
    }

    func testStart_WhenStdoutAndStderrProduced_AppendsToLogsAndCanClear() async {
        let session = MockRuntimeSession(
            pid: 9001,
            waitResult: .success(
                SKProcessResult(
                    stdoutData: Data(),
                    stderrData: Data(),
                    exitCode: 0,
                    timedOut: false,
                    truncated: false
                )
            ),
            stdoutChunks: [Data("hello from out\n".utf8)],
            stderrChunks: [Data("warn from err\n".utf8)]
        )
        let service = XcodeMCPKitRuntimeService(
            executableResolver: { URL(fileURLWithPath: "/tmp/xcodemcpkit") },
            sessionFactory: { _ in session }
        )

        await service.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(service.logsText.contains("[stdout] hello from out"))
        XCTAssertTrue(service.logsText.contains("[stderr] warn from err"))

        service.clearLogs()
        XCTAssertEqual(service.logsText, "")

        await service.stop(force: false)
    }
}

actor MockRuntimeSession: XcodeMCPKitRuntimeSessioning {
    let pid: Int32
    private(set) var running: Bool = true
    private(set) var terminateCallCount = 0
    private(set) var signalCallCount = 0
    private let waitResult: Result<SKProcessResult, Error>
    private let ignoreTerminate: Bool
    private let waitReturnDelayNanoseconds: UInt64
    private let stdoutChunks: [Data]
    private let stderrChunks: [Data]

    init(
        pid: Int32,
        waitResult: Result<SKProcessResult, Error>,
        ignoreTerminate: Bool = false,
        waitReturnDelayNanoseconds: UInt64 = 0,
        stdoutChunks: [Data] = [],
        stderrChunks: [Data] = []
    ) {
        self.pid = pid
        self.waitResult = waitResult
        self.ignoreTerminate = ignoreTerminate
        self.waitReturnDelayNanoseconds = waitReturnDelayNanoseconds
        self.stdoutChunks = stdoutChunks
        self.stderrChunks = stderrChunks
    }

    func wait() async throws -> SKProcessResult {
        while running {
            try? await Task.sleep(nanoseconds: 20_000_000)
            switch waitResult {
            case .failure:
                running = false
            case .success:
                break
            }
        }
        if waitReturnDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: waitReturnDelayNanoseconds)
        }
        return try waitResult.get()
    }

    func terminate() async {
        terminateCallCount += 1
        if ignoreTerminate { return }
        running = false
    }

    func isRunning() async -> Bool {
        running
    }

    func sendSignal(_ signal: Int32) async {
        signalCallCount += 1
        running = false
    }

    func stdoutStream() async -> AsyncStream<Data> {
        AsyncStream { continuation in
            let chunks = stdoutChunks
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    func stderrStream() async -> AsyncStream<Data> {
        AsyncStream { continuation in
            let chunks = stderrChunks
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

@MainActor
extension XcodeMCPKitRuntimeServiceTests {
    func testStopKillRaceDoesNotSurfaceUnexpectedExitNine() async {
        let session = MockRuntimeSession(
            pid: 9900,
            waitResult: .failure(SKProcessRunError.nonZeroExit(exitCode: 9, stdoutData: Data(), stderrData: Data())),
            ignoreTerminate: true,
            waitReturnDelayNanoseconds: 250_000_000
        )
        let service = XcodeMCPKitRuntimeService(
            executableResolver: { URL(fileURLWithPath: "/tmp/xcodemcpkit") },
            sessionFactory: { _ in session },
            stopTimeoutNanoseconds: 50_000_000
        )

        await service.start()
        await service.stop(force: false)
        try? await Task.sleep(nanoseconds: 400_000_000)

        if case .idle = service.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected idle after stop kill race, got \(service.state)")
        }
    }
}
