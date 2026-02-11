import Foundation
import Testing
@testable import CodexCLIKit
@testable import CodexAppServerKit

@Suite("CodexAppServerKit")
struct CodexAppServerKitTests {
    private var executor: CodexCommandExecutor {
        CodexCommandExecutor()
    }

    private func collectMethodEnumStrings(from object: Any) -> Set<String> {
        var results = Set<String>()
        if let dict = object as? [String: Any] {
            if let method = dict["method"] as? [String: Any],
               let values = method["enum"] as? [String] {
                results.formUnion(values)
            }
            for value in dict.values {
                results.formUnion(collectMethodEnumStrings(from: value))
            }
            return results
        }
        if let array = object as? [Any] {
            for value in array {
                results.formUnion(collectMethodEnumStrings(from: value))
            }
        }
        return results
    }

    @Test("Initialize app-server and read account")
    func initializeAndReadAccount() async throws {
        guard executor.resolveExecutable() != nil else { return }

        let session = CodexAppServerSession(startupArguments: ["app-server"])
        defer {
            Task { await session.shutdown() }
        }

        try await session.initialize(clientName: "providers-tests", clientVersion: "0.0.1", experimentalApi: true)
        let params = try CodexAppServerSession.encodeParams(["refreshToken": false])
        let response = try await session.request(method: "account/read", paramsData: params)

        let dict = response.result as? [String: Any]
        #expect(dict != nil)
        #expect(dict?["requiresOpenaiAuth"] != nil)
    }

    @Test("Wait for account/updated notification after login/start")
    func waitForAccountUpdatedNotification() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else { return }

        let script = #"""
import json
import sys

for line in sys.stdin:
    msg = json.loads(line)
    mid = msg.get("id")
    method = msg.get("method")
    if method == "initialize" and mid is not None:
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"ok":True}}) + "\n")
        sys.stdout.flush()
    elif method == "initialized":
        continue
    elif method == "account/login/start" and mid is not None:
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"type":"chatgptAuthTokens"}}) + "\n")
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","method":"account/updated","params":{"authMode":"chatgptAuthTokens"}}) + "\n")
        sys.stdout.flush()
"""#

        let session = CodexAppServerSession(
            executable: "/usr/bin/python3",
            startupArguments: ["-u", "-c", script]
        )
        defer {
            Task { await session.shutdown() }
        }

        try await session.initialize(clientName: "providers-tests", clientVersion: "0.0.1", experimentalApi: true)
        async let updated = session.waitForNotification(method: .accountUpdated, timeout: 2)
        _ = try await session.request(
            method: .accountLoginStart,
            params: ["type": "chatgptAuthTokens", "idToken": "id", "accessToken": "access"]
        )
        let notification = try await updated
        #expect(notification.method == "account/updated")
    }

    @Test("App-server method enums match generated JSON schema")
    func methodEnumsMatchSchema() async throws {
        guard executor.resolveExecutable() != nil else { return }

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-schema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try await executor.execute(args: ["app-server", "generate-json-schema", "--out", tempRoot.path], timeout: 30)

        let clientData = try Data(contentsOf: tempRoot.appendingPathComponent("ClientRequest.json"))
        let clientObject = try JSONSerialization.jsonObject(with: clientData)
        let clientMethods = collectMethodEnumStrings(from: clientObject)
        #expect(clientMethods == Set(CodexAppServerMethod.allCases.map(\.rawValue)))

        let notificationData = try Data(contentsOf: tempRoot.appendingPathComponent("ServerNotification.json"))
        let notificationObject = try JSONSerialization.jsonObject(with: notificationData)
        let notificationMethods = collectMethodEnumStrings(from: notificationObject)
        #expect(notificationMethods == Set(CodexAppServerServerNotification.allCases.map(\.rawValue)))

        let requestData = try Data(contentsOf: tempRoot.appendingPathComponent("ServerRequest.json"))
        let requestObject = try JSONSerialization.jsonObject(with: requestData)
        let requestMethods = collectMethodEnumStrings(from: requestObject)
        #expect(requestMethods == Set(CodexAppServerServerRequest.allCases.map(\.rawValue)))
    }
}
