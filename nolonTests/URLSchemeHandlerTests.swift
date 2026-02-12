import XCTest
@testable import nolon

@MainActor
final class URLSchemeHandlerTests: XCTestCase {
    func testBDD_GivenNolonURL_WhenNormalizing_ThenReturnsHTTPSURL() {
        let url = URL(string: "nolon://github.com/openai/codex")!

        let normalized = URLSchemeHandler.normalizeIncomingURL(url)

        XCTAssertEqual(normalized?.absoluteString, "https://github.com/openai/codex")
    }

    func testBDD_GivenNlnURLWithQuery_WhenNormalizing_ThenPreservesPathAndQuery() {
        let url = URL(string: "nln://example.com/repo/path?ref=main")!

        let normalized = URLSchemeHandler.normalizeIncomingURL(url)

        XCTAssertEqual(normalized?.absoluteString, "https://example.com/repo/path?ref=main")
    }

    func testBDD_GivenUnsupportedScheme_WhenNormalizing_ThenReturnsNil() {
        let url = URL(string: "https://example.com/repo")!

        let normalized = URLSchemeHandler.normalizeIncomingURL(url)

        XCTAssertNil(normalized)
    }
}
