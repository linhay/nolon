import XCTest
@testable import nolon

final class ResourceCardCopySupportTests: XCTestCase {
    func testBDD_GivenWhitespaceWrappedTitle_WhenNormalize_ThenTrimmedTitleReturned() {
        let title = ResourceCardCopySupport.normalizedTitle("  Skill Title \n")
        XCTAssertEqual(title, "Skill Title")
    }

    func testBDD_GivenBlankTitle_WhenNormalize_ThenReturnsNil() {
        let title = ResourceCardCopySupport.normalizedTitle(" \n\t ")
        XCTAssertNil(title)
    }

    func testBDD_GivenValidTitle_WhenCopyTitle_ThenWritesOnlyTrimmedTitle() {
        var copiedText: String?
        ResourceCardCopySupport.copyTitle("  MCP Server  ") { text in
            copiedText = text
        }

        XCTAssertEqual(copiedText, "MCP Server")
    }

    func testBDD_GivenBlankTitle_WhenCopyTitle_ThenDoesNotWriteToPasteboard() {
        var writeCount = 0
        ResourceCardCopySupport.copyTitle("   ") { _ in
            writeCount += 1
        }

        XCTAssertEqual(writeCount, 0)
    }
}
