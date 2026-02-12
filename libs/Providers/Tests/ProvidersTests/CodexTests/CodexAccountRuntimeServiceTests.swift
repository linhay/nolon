import Foundation
import Testing
@testable import CodexCLIKit
@testable import CodexAppServerKit

@Suite("CodexAccountRuntimeService")
struct CodexAccountRuntimeServiceTests {
    @Test("Reads account and rate limits via runtime service")
    func readAccountAndRateLimits() async throws {
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
}
