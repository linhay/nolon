import Foundation
import Testing
import JsonRPCKit

@Suite("JsonRPCKit")
struct JsonRPCKitTests {
    private actor NotificationRecorder {
        private(set) var methods: [String] = []

        func record(_ method: String) {
            methods.append(method)
        }

        func hasMethod(_ method: String) -> Bool {
            methods.contains(method)
        }
    }

    private struct TestError: LocalizedError, Sendable {
        let message: String
        var errorDescription: String? { message }
    }

    @Test("BDD: Given JSON-RPC request when mock server responds then result and notification are received")
    func requestRoundTripAndNotification() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    method = msg.get("method")
    if method == "echo":
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","method":"notice","params":{"kind":"before-echo"}}) + "\\n")
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":{"ok":True,"params":msg.get("params")}}) + "\\n")
        sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        let recorder = NotificationRecorder()
        await session.setNotificationHandler { notification in
            await recorder.record(notification.method)
        }

        let params = try JsonRPCLineProcessSession.encodeParams(["k": "v"])
        let response = try await session.request(method: "echo", paramsData: params)

        let result = response.result as? [String: Any]
        #expect(result?["ok"] as? Bool == true)
        let echoed = result?["params"] as? [String: Any]
        #expect(echoed?["k"] as? String == "v")

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if await recorder.hasMethod("notice") { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(await recorder.hasMethod("notice"))
    }

    @Test("TDD: Given RPC error response when parsing then error object is exposed")
    func errorResponse() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    if msg.get("method") == "fail":
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":msg["id"],"error":{"code":123,"message":"boom"}}) + "\\n")
        sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        let response = try await session.request(method: "fail")
        #expect(response.error?.code == 123)
        #expect(response.error?.message == "boom")
    }
}
