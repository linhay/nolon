import Foundation
import Testing
@testable import CodexProvider

@Suite("CodexSessionEventParser")
struct CodexSessionEventParserTests {
    @Test("Parse response_item as typed session event")
    func parseResponseItem() throws {
        let line = """
        {
          "timestamp": "2026-02-11T12:00:01Z",
          "type": "response_item",
          "payload": {
            "type": "message",
            "role": "assistant",
            "content": [
              { "type": "output_text", "text": "Done" }
            ]
          }
        }
        """

        let event = try CodexSessionEventParser.parseEventLine(text: line)
        if case let .responseItem(timestamp, payload) = event {
            #expect(timestamp == "2026-02-11T12:00:01Z")
            if case let .message(role, content, _) = payload.kind {
                #expect(role == "assistant")
                #expect(content.count == 1)
            } else {
                Issue.record("Expected response_item.message")
            }
        } else {
            Issue.record("Expected response_item event")
        }
    }

    @Test("Parse event_msg and compacted as typed session events")
    func parseEventMessageAndCompacted() throws {
        let eventLine = """
        {
          "timestamp": "2026-02-11T12:00:02Z",
          "type": "event_msg",
          "payload": {
            "type": "user_message",
            "message": "hello"
          }
        }
        """

        let compactedLine = """
        {
          "timestamp": "2026-02-11T12:00:03Z",
          "type": "compacted",
          "payload": {
            "message": "summary"
          }
        }
        """

        let parsedEvent = try CodexSessionEventParser.parseEventLine(text: eventLine)
        if case let .eventMessage(timestamp, payload) = parsedEvent {
            #expect(timestamp == "2026-02-11T12:00:02Z")
            if case let .userMessage(user) = payload.kind {
                #expect(user.message == "hello")
            } else {
                Issue.record("Expected event_msg.user_message")
            }
        } else {
            Issue.record("Expected event_msg event")
        }

        let parsedCompacted = try CodexSessionEventParser.parseEventLine(text: compactedLine)
        if case let .compacted(timestamp, payload) = parsedCompacted {
            #expect(timestamp == "2026-02-11T12:00:03Z")
            #expect(payload.message == "summary")
        } else {
            Issue.record("Expected compacted event")
        }
    }

    @Test("Parse usage fast-path for session_meta, turn_context and token_count")
    func parseUsageFastPath() {
        let sessionLine = Data(#"{"timestamp":"2026-02-11T12:00:00Z","type":"session_meta","payload":{"id":"thread-1"}}"#.utf8)
        let turnContextLine = Data(#"{"timestamp":"2026-02-11T12:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}"#.utf8)
        let tokenLine = Data(#"{"timestamp":"2026-02-11T12:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"cached_input_tokens":3,"output_tokens":5,"total_tokens":15}}}}"#.utf8)
        let warningLine = Data(#"{"timestamp":"2026-02-11T12:00:03Z","type":"event_msg","payload":{"type":"warning","message":"warn"}}"#.utf8)

        if case let .sessionMeta(sessionID)? = CodexSessionEventParser.parseUsageEventLine(data: sessionLine) {
            #expect(sessionID == "thread-1")
        } else {
            Issue.record("Expected usage session_meta")
        }

        if case let .turnContext(model)? = CodexSessionEventParser.parseUsageEventLine(data: turnContextLine) {
            #expect(model == "gpt-5")
        } else {
            Issue.record("Expected usage turn_context")
        }

        if case let .tokenCount(timestamp, payload)? = CodexSessionEventParser.parseUsageEventLine(data: tokenLine) {
            #expect(timestamp == "2026-02-11T12:00:02Z")
            #expect(payload.model == "gpt-5")
            #expect(payload.lastUsage?.inputTokens == 10)
        } else {
            Issue.record("Expected usage token_count")
        }

        #expect(CodexSessionEventParser.parseUsageEventLine(data: warningLine) == nil)
    }

    @Test("Reduce usage line with total/last token usage and clamp cached tokens")
    func reduceUsageLineForTokenDelta() {
        let turnContextLine = Data(#"{"timestamp":"2026-02-11T12:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}} "#.utf8)
        let totalLine = Data(#"{"timestamp":"2026-02-11T12:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":30,"total_tokens":130}}}}"#.utf8)
        let totalLineSecond = Data(#"{"timestamp":"2026-02-11T12:00:03Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"cached_input_tokens":140,"output_tokens":40,"total_tokens":160}}}}"#.utf8)
        let lastUsageLine = Data(#"{"timestamp":"2026-02-11T12:00:04Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":7,"cached_input_tokens":20,"output_tokens":5,"total_tokens":12}}}}"#.utf8)

        let first = CodexSessionEventParser.reduceUsageLine(
            data: turnContextLine,
            currentModel: nil,
            previousTotals: nil
        )
        #expect(first?.updatedModel == "gpt-5")
        #expect(first?.tokenDelta == nil)

        let second = CodexSessionEventParser.reduceUsageLine(
            data: totalLine,
            currentModel: first?.updatedModel,
            previousTotals: first?.updatedTotals
        )
        #expect(second?.updatedModel == "gpt-5")
        #expect(second?.updatedTotals?.inputTokens == 100)
        #expect(second?.updatedTotals?.cachedInputTokens == 80)
        #expect(second?.updatedTotals?.outputTokens == 30)
        #expect(second?.tokenDelta?.inputTokens == 100)
        #expect(second?.tokenDelta?.cachedInputTokens == 80)
        #expect(second?.tokenDelta?.outputTokens == 30)

        let third = CodexSessionEventParser.reduceUsageLine(
            data: totalLineSecond,
            currentModel: second?.updatedModel,
            previousTotals: second?.updatedTotals
        )
        #expect(third?.updatedTotals?.inputTokens == 120)
        #expect(third?.updatedTotals?.cachedInputTokens == 140)
        #expect(third?.updatedTotals?.outputTokens == 40)
        #expect(third?.tokenDelta?.inputTokens == 20)
        #expect(third?.tokenDelta?.cachedInputTokens == 20)
        #expect(third?.tokenDelta?.outputTokens == 10)

        let fourth = CodexSessionEventParser.reduceUsageLine(
            data: lastUsageLine,
            currentModel: third?.updatedModel,
            previousTotals: third?.updatedTotals
        )
        #expect(fourth?.updatedTotals?.inputTokens == 120)
        #expect(fourth?.updatedTotals?.cachedInputTokens == 140)
        #expect(fourth?.updatedTotals?.outputTokens == 40)
        #expect(fourth?.tokenDelta?.inputTokens == 7)
        #expect(fourth?.tokenDelta?.cachedInputTokens == 7)
        #expect(fourth?.tokenDelta?.outputTokens == 5)
        #expect(fourth?.tokenDelta?.model == "gpt-5")
    }
}
