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
}

actor MockRuntimeSession: XcodeMCPKitRuntimeSessioning {
    let pid: Int32
    private(set) var running: Bool = true
    private(set) var terminateCallCount = 0
    private(set) var signalCallCount = 0
    private let waitResult: Result<SKProcessResult, Error>

    init(pid: Int32, waitResult: Result<SKProcessResult, Error>) {
        self.pid = pid
        self.waitResult = waitResult
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
        return try waitResult.get()
    }

    func terminate() async {
        terminateCallCount += 1
        running = false
    }

    func isRunning() async -> Bool {
        running
    }

    func sendSignal(_ signal: Int32) async {
        signalCallCount += 1
        running = false
    }
}
