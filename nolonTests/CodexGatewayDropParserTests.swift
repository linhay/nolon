import XCTest
@testable import nolon

final class CodexGatewayDropParserTests: XCTestCase {
    func testBDD_GivenLegacyRawUUID_WhenParsingDropPayload_ThenReturnsSameUUID() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        let parsed = CodexGatewayDropParser.accountIDs(fromLegacyStrings: [id.uuidString])

        XCTAssertEqual(parsed, [id])
    }

    func testBDD_GivenLegacyTextWithEmbeddedUUID_WhenParsingDropPayload_ThenExtractsUUID() {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let raw = "drag-item=\(id.uuidString);source=account-card"

        let parsed = CodexGatewayDropParser.accountIDs(fromLegacyStrings: [raw])

        XCTAssertEqual(parsed, [id])
    }

    func testBDD_GivenLegacyInvalidText_WhenParsingDropPayload_ThenReturnsEmpty() {
        let parsed = CodexGatewayDropParser.accountIDs(fromLegacyStrings: ["not-a-uuid"])

        XCTAssertTrue(parsed.isEmpty)
    }
}
