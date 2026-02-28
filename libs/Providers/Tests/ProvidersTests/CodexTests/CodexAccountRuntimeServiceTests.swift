import Foundation
import Testing
import STFilePath
@testable import CodexCLIKit
@testable import CodexAppServerKit

private actor StubTokenRefresher: CodexTokenRefreshing {
    private(set) var reasons: [CodexRefreshReason] = []
    let tokenPair: CodexTokenPair

    init(tokenPair: CodexTokenPair) {
        self.tokenPair = tokenPair
    }

    func refreshedTokens(reason: CodexRefreshReason) async throws -> CodexTokenPair {
        reasons.append(reason)
        return tokenPair
    }

    func capturedReasons() -> [CodexRefreshReason] {
        reasons
    }
}

@Suite("CodexAccountRuntimeService")
struct CodexAccountRuntimeServiceTests {
    @Test("Reads account and rate limits via runtime service")
    func readAccountAndRateLimits() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
    elif method == "account/read" and mid is not None:
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{
                "requiresOpenaiAuth":False,
                "account":{
                    "type":"chatgptAuthTokens",
                    "email":"dev@example.com",
                    "planType":"pro"
                }
            }
        }) + "\n")
        sys.stdout.flush()
    elif method == "account/rateLimits/read" and mid is not None:
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{
                "rateLimits":{
                    "primary":{"usedPercent":12.5,"windowDurationMins":300,"resetsAt":1735689600},
                    "secondary":None,
                    "credits":{"hasCredits":True,"unlimited":False,"balance":"19.25"}
                }
            }
        }) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")

        let account = try await service.readAccount(refreshToken: false)
        #expect(account.email == "dev@example.com")
        #expect(account.planType == "pro")
        #expect(account.requiresOpenaiAuth == false)
        #expect(account.authMode == .chatgptAuthTokens)

        let limits = try await service.readRateLimits()
        #expect(limits.primary?.usedPercent == 12.5)
        #expect(limits.primary?.windowDurationMins == 300)
        #expect(limits.primary?.resetsAt == 1735689600)
        #expect(limits.secondary == nil)
        #expect(limits.credits?.hasCredits == true)
        #expect(limits.credits?.unlimited == false)
        #expect(limits.credits?.balance == "19.25")
    }

    @Test("readAccount throws invalidPayload when response field type is invalid")
    func readAccountInvalidPayloadThrowsTypedError() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
    elif method == "account/read" and mid is not None:
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{
                "requiresOpenaiAuth":"nope",
                "account":{"type":"chatgptAuthTokens","email":"dev@example.com","planType":"pro"}
            }
        }) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        do {
            _ = try await service.readAccount(refreshToken: false)
            Issue.record("Expected invalid payload error")
        } catch let error as CodexAccountRuntimeServiceError {
            guard case let .invalidPayload(context, _) = error else {
                Issue.record("Expected invalidPayload, got: \(error)")
                return
            }
            #expect(context == "account/read")
        } catch {
            Issue.record("Expected CodexAccountRuntimeServiceError, got: \(error)")
        }
    }

    @Test("readRateLimits throws invalidPayload when rateLimits object is missing")
    func readRateLimitsInvalidPayloadThrowsTypedError() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
    elif method == "account/rateLimits/read" and mid is not None:
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{}}) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        do {
            _ = try await service.readRateLimits()
            Issue.record("Expected invalid payload error")
        } catch let error as CodexAccountRuntimeServiceError {
            guard case let .invalidPayload(context, _) = error else {
                Issue.record("Expected invalidPayload, got: \(error)")
                return
            }
            #expect(context == "account/rateLimits/read")
        } catch {
            Issue.record("Expected CodexAccountRuntimeServiceError, got: \(error)")
        }
    }

    @Test("switchAccount sends chatgptAccountId in login/start payload")
    func switchAccountIncludesChatgptAccountID() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
        params = msg.get("params") or {}
        if "chatgptAccountId" not in params:
            sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"error":{"code":-32600,"message":"missing chatgptAccountId"}}) + "\n")
            sys.stdout.flush()
            continue
        if params.get("chatgptAccountId") != "acct-777":
            sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"error":{"code":-32602,"message":"bad chatgptAccountId"}}) + "\n")
            sys.stdout.flush()
            continue
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"type":"chatgptAuthTokens"}}) + "\n")
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","method":"account/updated","params":{"authMode":"chatgptAuthTokens"}}) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        try await service.switchAccount(idToken: "id-token", accessToken: "access-token", chatgptAccountID: "acct-777")
    }

    @Test("Starts chatgpt login and validates loginId/authUrl")
    func startChatGPTLoginReturnsLoginIDAndURL() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
        params = msg.get("params") or {}
        if params.get("type") != "chatgpt":
            sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"error":{"code":-32602,"message":"expected type=chatgpt"}}) + "\n")
            sys.stdout.flush()
            continue
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{"type":"chatgpt","loginId":"login-123","authUrl":"https://example.com/login"}
        }) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        let result = try await service.startChatGPTLogin()
        #expect(result.loginID == "login-123")
        #expect(result.authURL.absoluteString == "https://example.com/login")
    }

    @Test("startChatGPTLogin throws typed error when loginId is missing")
    func startChatGPTLoginMissingLoginIDThrowsTypedError() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{"type":"chatgpt","authUrl":"https://example.com/login"}
        }) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        do {
            _ = try await service.startChatGPTLogin()
            Issue.record("Expected missing loginId typed error")
        } catch let error as CodexAccountRuntimeServiceError {
            guard case .loginStartMissingLoginID = error else {
                Issue.record("Expected loginStartMissingLoginID, got: \(error)")
                return
            }
        } catch {
            Issue.record("Expected CodexAccountRuntimeServiceError, got: \(error)")
        }
    }

    @Test("Awaits chatgpt login completion notification")
    func awaitChatGPTLoginCompletionSucceeds() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "method":"account/login/completed",
            "params":{"loginId":"login-abc","success":True}
        }) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        try await service.awaitChatGPTLoginCompletion(loginID: "login-abc", timeout: 2)
    }

    @Test("Cancels chatgpt login and calls account/login/cancel")
    func cancelChatGPTLoginCallsCancelMethod() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
    elif method == "account/login/cancel" and mid is not None:
        params = msg.get("params") or {}
        if params.get("loginId") != "login-cancel-me":
            sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"error":{"code":-32602,"message":"bad loginId"}}) + "\n")
            sys.stdout.flush()
            continue
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"ok":True}}) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        try await service.cancelChatGPTLogin(loginID: "login-cancel-me")
    }

    @Test("Logs out via account/logout request")
    func logoutCallsAccountLogout() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
    elif method == "account/logout" and mid is not None:
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"ok":True}}) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        try await service.logout()
    }

    @Test("Refreshes chatgpt auth tokens from server request and returns full token payload")
    func tokenRefreshServerRequestReturnsFullTokenPayload() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }
        let markerPath = "/tmp/codex-runtime-refresh-\(UUID().uuidString).txt"
        defer { try? STPath(markerPath).delete() }

        let script = #"""
import json
import os
import sys

marker = sys.argv[1]

for line in sys.stdin:
    msg = json.loads(line)
    mid = msg.get("id")
    method = msg.get("method")
    if method == "initialize" and mid is not None:
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":mid,"result":{"ok":True}}) + "\n")
        sys.stdout.flush()
    elif method == "initialized":
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":"srv-1",
            "method":"account/chatgptAuthTokens/refresh",
            "params":{"reason":"unauthorized"}
        }) + "\n")
        sys.stdout.flush()
    elif mid == "srv-1":
        result = msg.get("result") or {}
        if result.get("idToken") != "id-new" or result.get("accessToken") != "access-new":
            with open(marker, "w", encoding="utf-8") as f:
                f.write("missing-token-pair")
            continue
        if result.get("chatgptAccountId") != "acct-999":
            with open(marker, "w", encoding="utf-8") as f:
                f.write("missing-chatgptAccountId")
            continue
        with open(marker, "w", encoding="utf-8") as f:
            f.write("ok")
        sys.stdout.write(json.dumps({"jsonrpc":"2.0","id":"srv-1","result":{"ok":True}}) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script, markerPath]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        let refresher = StubTokenRefresher(
            tokenPair: CodexTokenPair(
                idToken: "id-new",
                accessToken: "access-new",
                chatgptAccountID: "acct-999"
            )
        )
        await service.setTokenRefresher(refresher)
        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")

        // Give server request/response loop a short time slice.
        try await Task.sleep(nanoseconds: 200_000_000)

        let reasons = await refresher.capturedReasons()
        #expect(reasons == [.unauthorized])
        #expect(STPath(markerPath).isExists)
        #expect((try? String(contentsOfFile: markerPath, encoding: .utf8)) == "ok")
    }

    @Test("End-to-end login flow reads account and rate limits after completion")
    func endToEndLoginThenReadAccountAndRateLimits() async throws {
        guard STPath("/usr/bin/python3").permission.contains(.executable) else { return }

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
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{"type":"chatgpt","loginId":"login-e2e","authUrl":"https://example.com/e2e-login"}
        }) + "\n")
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "method":"account/login/completed",
            "params":{"loginId":"login-e2e","success":True}
        }) + "\n")
        sys.stdout.flush()
    elif method == "account/read" and mid is not None:
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{
                "requiresOpenaiAuth":False,
                "account":{"type":"chatgptAuthTokens","email":"e2e@example.com","planType":"plus"}
            }
        }) + "\n")
        sys.stdout.flush()
    elif method == "account/rateLimits/read" and mid is not None:
        sys.stdout.write(json.dumps({
            "jsonrpc":"2.0",
            "id":mid,
            "result":{
                "rateLimits":{
                    "primary":{"usedPercent":34.0,"windowDurationMins":300,"resetsAt":1735689600},
                    "secondary":{"usedPercent":12.0,"windowDurationMins":10080,"resetsAt":1735776000},
                    "credits":{"hasCredits":True,"unlimited":False,"balance":"8.50"}
                }
            }
        }) + "\n")
        sys.stdout.flush()
"""#

        let service = CodexAccountRuntimeService(
            executable: "/usr/bin/python3",
            session: CodexAppServerSession(
                executable: "/usr/bin/python3",
                startupArguments: ["-u", "-c", script]
            )
        )
        defer {
            Task { await service.shutdown() }
        }

        try await service.initialize(clientName: "providers-tests", clientVersion: "0.0.1")
        async let completion: Void = service.awaitChatGPTLoginCompletion(loginID: "login-e2e", timeout: 2)
        let started = try await service.startChatGPTLogin()
        #expect(started.loginID == "login-e2e")
        #expect(started.authURL.absoluteString == "https://example.com/e2e-login")
        try await completion

        let account = try await service.readAccount(refreshToken: false)
        #expect(account.email == "e2e@example.com")
        #expect(account.planType == "plus")
        #expect(account.authMode == .chatgptAuthTokens)

        let rateLimits = try await service.readRateLimits()
        #expect(rateLimits.primary?.usedPercent == 34.0)
        #expect(rateLimits.secondary?.usedPercent == 12.0)
        #expect(rateLimits.credits?.balance == "8.50")
    }
}
