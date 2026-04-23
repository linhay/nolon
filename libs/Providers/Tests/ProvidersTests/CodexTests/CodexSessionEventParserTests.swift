import Foundation
import Testing
@testable import CodexProvider

@Suite("CodexSessionEventParser")
struct CodexSessionEventParserTests {
    @Test("Given a huge response item payload, when reading the fast rollout envelope, then parser returns the top-level timestamp and type")
    func fastTopLevelEnvelopeReadsHugeResponseItemPrefix() {
        let hugeOutput = String(repeating: "B", count: 2_000_000)
        let line = """
        {"timestamp":"2026-04-20T20:38:33.464Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call_1","output":"\(hugeOutput)"}}
        """

        let envelope = CodexSessionEventParser.fastTopLevelEnvelope(data: Data(line.utf8))

        #expect(envelope?.timestamp == "2026-04-20T20:38:33.464Z")
        #expect(envelope?.type == "response_item")
        #expect(CodexSessionEventParser.parseUsageEventLine(data: Data(line.utf8)) == nil)
    }

    @Test("Given top-level timestamp and type appear after a nested payload object, when reading the fast rollout envelope, then parser still resolves the top-level fields")
    func fastTopLevelEnvelopeIgnoresNestedPayloadKeys() {
        let line = """
        {"payload":{"type":"nested","timestamp":"1999-01-01T00:00:00Z"},"timestamp":"2026-04-10T10:00:00Z","type":"session_meta"}
        """

        let envelope = CodexSessionEventParser.fastTopLevelEnvelope(data: Data(line.utf8))

        #expect(envelope?.timestamp == "2026-04-10T10:00:00Z")
        #expect(envelope?.type == "session_meta")
    }
}
