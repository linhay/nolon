import Foundation
import Testing
@testable import CodexProvider

@Suite("Codex Generated Files Parser")
struct CodexGeneratedFilesParserTests {
    @Test("Parse auth.json with JWT claims")
    func parseAuthJSON() throws {
        let jwt = Self.makeJWT(payload: """
        {
          "email": "user@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_plan_type": "pro",
            "chatgpt_user_id": "user-123",
            "chatgpt_account_id": "org-456"
          }
        }
        """)

        let json = """
        {
          "auth_mode": "chatgpt",
          "OPENAI_API_KEY": null,
          "tokens": {
            "id_token": "\(jwt)",
            "access_token": "access-abc",
            "refresh_token": "refresh-def",
            "account_id": "org-456"
          },
          "last_refresh": "2026-02-11T12:00:00Z"
        }
        """

        let parsed = try CodexGeneratedFilesParser.parseAuth(jsonString: json)
        #expect(parsed.authMode == .chatgpt)
        #expect(parsed.tokens?.accessToken == "access-abc")
        #expect(parsed.tokens?.idTokenClaims?.email == "user@example.com")
        #expect(parsed.tokens?.idTokenClaims?.chatgptPlanType == "pro")
        #expect(parsed.tokens?.idTokenClaims?.chatgptAccountID == "org-456")
    }

    @Test("Parse rollout session_meta and token_count event")
    func parseRolloutLines() throws {
        let sessionLine = """
        {
          "timestamp": "2026-02-11T12:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": "thread-001",
            "cwd": "/tmp/project",
            "source": "cli",
            "model_provider": "openai",
            "git": {
              "commit_hash": "abc",
              "branch": "main",
              "repository_url": "https://example.com/repo.git"
            }
          }
        }
        """
        let parsedSession = try CodexGeneratedFilesParser.parseRolloutLine(text: sessionLine)
        if case let .sessionMeta(meta) = parsedSession.item {
            #expect(meta.id == "thread-001")
            #expect(meta.cwd == "/tmp/project")
            #expect(meta.git?.branch == "main")
        } else {
            Issue.record("Expected session_meta")
        }

        let tokenLine = """
        {
          "timestamp": "2026-02-11T12:00:01Z",
          "type": "event_msg",
          "payload": {
            "type": "token_count",
            "info": {
              "model": "gpt-5",
              "total_token_usage": {
                "input_tokens": 200,
                "cached_input_tokens": 50,
                "output_tokens": 100,
                "total_tokens": 300
              },
              "last_token_usage": {
                "input_tokens": 20,
                "cached_input_tokens": 5,
                "output_tokens": 10,
                "total_tokens": 30
              }
            }
          }
        }
        """
        let parsedToken = try CodexGeneratedFilesParser.parseRolloutLine(text: tokenLine)
        if case let .tokenCount(tokenCount) = parsedToken.item {
            #expect(tokenCount.model == "gpt-5")
            #expect(tokenCount.totalUsage?.inputTokens == 200)
            #expect(tokenCount.totalUsage?.cachedInputTokens == 50)
            #expect(tokenCount.lastUsage?.outputTokens == 10)
        } else {
            Issue.record("Expected token_count")
        }
    }

    private static func makeJWT(payload: String) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        func encode(_ raw: String) -> String {
            Data(raw.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(encode(header)).\(encode(payload)).sig"
    }
}
