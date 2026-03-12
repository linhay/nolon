import XCTest
@testable import nolon

@MainActor
final class CodexPIDSystemLogServiceTests: XCTestCase {
    func testBDD_GivenLongLogs_WhenFetching_ThenKeepsOnlyTailLines() async throws {
        let service = CodexPIDSystemLogService(commandRunner: { _, _ in
            (1...6).map { "line-\($0)" }.joined(separator: "\n")
        })

        let output = try await service.fetchLogs(pid: 123, lastSeconds: 120, maxLines: 3)

        XCTAssertEqual(output, "line-4\nline-5\nline-6")
    }

    func testBDD_GivenEmptyLogs_WhenFetching_ThenReturnsEmptyString() async throws {
        let service = CodexPIDSystemLogService(commandRunner: { _, _ in "  \n  " })

        let output = try await service.fetchLogs(pid: 456, lastSeconds: 120, maxLines: 20)

        XCTAssertEqual(output, "")
    }

    func testBDD_GivenInvalidPID_WhenFetching_ThenThrowsInvalidArguments() async {
        let service = CodexPIDSystemLogService(commandRunner: { _, _ in "" })

        do {
            _ = try await service.fetchLogs(pid: 1, lastSeconds: 120, maxLines: 20)
            XCTFail("Expected invalid arguments")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("pid"))
        }
    }
}
