import XCTest
import NolonResourceKit

final class PiAuthStatusParserTests: XCTestCase {
    func testBDD_GivenPiAuthPayloadWithRootEmail_WhenParsing_ThenReturnsAvailableStatusWithEmail() throws {
        let data = try XCTUnwrap(
            """
            {
              "email": "pi@example.com"
            }
            """.data(using: .utf8)
        )

        let status = PiAuthStatusParser.parse(data)

        XCTAssertEqual(status, .available(email: "pi@example.com"))
    }

    func testBDD_GivenPiAuthPayloadWithNestedUserEmail_WhenParsing_ThenReturnsAvailableStatusWithEmail() throws {
        let data = try XCTUnwrap(
            """
            {
              "user": {
                "email": "nested@example.com"
              }
            }
            """.data(using: .utf8)
        )

        let status = PiAuthStatusParser.parse(data)

        XCTAssertEqual(status, .available(email: "nested@example.com"))
    }

    func testBDD_GivenInvalidPiAuthPayload_WhenParsing_ThenReturnsInvalidStatus() throws {
        let data = try XCTUnwrap("not-json".data(using: .utf8))

        let status = PiAuthStatusParser.parse(data)

        XCTAssertEqual(status, .invalid)
    }
}
