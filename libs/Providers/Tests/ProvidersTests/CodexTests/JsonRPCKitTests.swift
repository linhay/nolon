import Foundation
import Testing
import STFilePath
import JsonRPCKit
import STJSON

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
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
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
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
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

    @Test("BDD: Given server request when client handler is set then session replies with result")
    func serverRequestRoundTrip() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    if msg.get("method") != "echo":
        continue
    server_req = {"jsonrpc":"2.0","id":"srv-1","method":"fetch_context","params":{"topic":"swift"}}
    sys.stdout.write(json.dumps(server_req) + "\\n")
    sys.stdout.flush()

    callback_line = sys.stdin.readline()
    callback_msg = json.loads(callback_line)
    result_obj = callback_msg.get("result") or {}
    value = result_obj.get("answer", "")

    sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":{"server":"ok","value":value}}) + "\\n")
    sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        await session.setServerRequestHandler { request in
            #expect(request.method == "fetch_context")
            let params = request.params as? [String: Any]
            #expect(params?["topic"] as? String == "swift")
            return ["answer": "context-ready"]
        }

        let response = try await session.request(method: "echo")
        let result = response.result as? [String: Any]
        #expect(result?["server"] as? String == "ok")
        #expect(result?["value"] as? String == "context-ready")
    }

    @Test("TDD: Given reserved rpc.* notification when parsing then it is ignored by protocol guard")
    func reservedRPCPrefixNotificationIsIgnored() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

sys.stdout.write(json.dumps({"jsonrpc":"2.0","method":"rpc.forbidden","params":{"k":"v"}}) + "\\n")
sys.stdout.flush()

for line in sys.stdin:
    msg = json.loads(line)
    if msg.get("method") == "echo":
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":{"ok":True}}) + "\\n")
        sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        let recorder = NotificationRecorder()
        await session.setNotificationHandler { notification in
            await recorder.record(notification.method)
        }

        _ = try await session.request(method: "echo")
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(await recorder.hasMethod("rpc.forbidden") == false)
    }

    @Test("TDD: Given reserved rpc.* outbound method when requesting then request is rejected before send")
    func reservedRPCPrefixOutboundMethodIsRejected() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    mid = msg.get("id")
    if mid is not None:
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"ok":True}}) + "\\n")
        sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        do {
            _ = try await session.request(method: "rpc.forbidden", paramsData: Data("{}".utf8))
            Issue.record("Expected protocol validation failure")
        } catch let error as JsonRPCSessionError {
            guard case .protocolViolation = error else {
                Issue.record("Expected protocolViolation, got: \(error)")
                return
            }
        } catch {
            Issue.record("Expected JsonRPCSessionError, got: \(error)")
        }
    }

    @Test("TDD: Given invalid response containing both result and error when parsing then request fails")
    func invalidResponseWithResultAndErrorIsRejected() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    mid = msg.get("id")
    if mid is None:
        continue
    sys.stdout.write(json.dumps({
        "jsonrpc":"2.0",
        "id":mid,
        "result":{"ok":True},
        "error":{"code":123,"message":"boom"}
    }) + "\\n")
    sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        do {
            _ = try await session.request(method: "echo")
            Issue.record("Expected invalid response rejection")
        } catch let error as JsonRPCSessionError {
            guard case .invalidResponse = error else {
                Issue.record("Expected invalidResponse, got: \(error)")
                return
            }
        } catch {
            Issue.record("Expected JsonRPCSessionError, got: \(error)")
        }
    }

    @Test("TDD: Given invalid response error object missing message when parsing then stable payload error is returned")
    func invalidResponseMissingErrorMessageUsesStablePayloadDescription() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    mid = msg.get("id")
    if mid is None:
        continue
    sys.stdout.write(json.dumps({
        "jsonrpc":"2.0",
        "id":mid,
        "error":{"code":123}
    }) + "\\n")
    sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        do {
            _ = try await session.request(method: "echo")
            Issue.record("Expected invalid response rejection")
        } catch let error as JsonRPCSessionError {
            guard case let .invalidResponse(message) = error else {
                Issue.record("Expected invalidResponse, got: \(error)")
                return
            }
            #expect(message.contains("Invalid JSON-RPC response payload"))
        } catch {
            Issue.record("Expected JsonRPCSessionError, got: \(error)")
        }
    }

    @Test("TDD: Given server closes stdin immediately when requesting then session returns transport error instead of crashing on SIGPIPE")
    func closedStdinDuringSendReturnsTransportError() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import sys
import time

sys.stdin.close()
time.sleep(0.2)
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        do {
            _ = try await session.request(method: "echo")
            Issue.record("Expected transport failure when child stdin is closed")
        } catch let error as JsonRPCSessionError {
            guard case let .transport(message) = error else {
                Issue.record("Expected transport error, got: \(error)")
                return
            }
            #expect(message.contains("stdin") || message.contains("terminated"))
        } catch {
            Issue.record("Expected JsonRPCSessionError, got: \(error)")
        }
    }

    @Test("BDD: Given response missing jsonrpc field when parsing then session accepts legacy payload")
    func responseMissingJSONRPCFieldIsAccepted() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    mid = msg.get("id")
    if mid is None:
        continue
    sys.stdout.write(json.dumps({
        "id":mid,
        "result":{"ok":True}
    }) + "\\n")
    sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        let response = try await session.request(method: "echo")
        let result = response.result as? [String: Any]
        #expect(result?["ok"] as? Bool == true)
        #expect(response.error == nil)
    }

    @Test("TDD: Given AnyCodable params when encoding then params data is generated")
    func encodeParamsSupportsAnyCodablePayload() throws {
        let params: [String: Any] = [
            "meta": [
                "id": AnyCodable("acct-1"),
                "flags": [AnyCodable(true), AnyCodable(2)],
            ],
        ]

        let data = try JsonRPCLineProcessSession.encodeParams(params)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let meta = object?["meta"] as? [String: Any]
        #expect(meta?["id"] as? String == "acct-1")
        let flags = meta?["flags"] as? [Any]
        #expect(flags?.count == 2)
    }

    @Test("TDD: Given Bool params when encoding then bool remains JSON boolean")
    func encodeParamsPreservesBoolType() throws {
        let params: [String: Any] = [
            "capabilities": [
                "experimentalApi": true,
            ],
        ]

        let data = try JsonRPCLineProcessSession.encodeParams(params)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"experimentalApi\":true"))
        #expect(json.contains("\"experimentalApi\":1") == false)
    }

    @Test("TDD: Given server handler returns AnyCodable when replying then response stays valid JSON-RPC")
    func serverRequestReplySupportsAnyCodablePayload() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else {
            return
        }

        let script = """
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    if msg.get("method") != "echo":
        continue
    sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":"srv-2","method":"fetch_anycodable","params":{"topic":"swift"}}) + "\\n")
    sys.stdout.flush()

    callback_line = sys.stdin.readline()
    callback_msg = json.loads(callback_line)
    result_obj = callback_msg.get("result") or {}
    value = result_obj.get("answer")

    sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":{"ok": value == "context-ready"}}) + "\\n")
    sys.stdout.flush()
"""

        let session = JsonRPCLineProcessSession(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            startupArguments: ["-u", "-c", script]
        ) { message in
            TestError(message: message)
        }
        defer { Task { await session.shutdown() } }

        await session.setServerRequestHandler { request in
            #expect(request.method == "fetch_anycodable")
            return ["answer": AnyCodable("context-ready")]
        }

        let response = try await session.request(method: "echo")
        let result = response.result as? [String: Any]
        #expect(result?["ok"] as? Bool == true)
    }
}
