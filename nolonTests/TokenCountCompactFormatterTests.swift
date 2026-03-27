import XCTest
import NolonUIFoundation
@testable import nolon

final class TokenCountCompactFormatterTests: XCTestCase {
    func testBDD_GivenValueBelowOneThousand_WhenFormatting_ThenReturnsRawNumber() {
        XCTAssertEqual(TokenCountFormatters.compact(999), "999")
    }

    func testBDD_GivenValueInThousands_WhenFormatting_ThenUsesKUnit() {
        XCTAssertEqual(TokenCountFormatters.compact(1_500), "1.5K")
    }

    func testBDD_GivenValueInMillions_WhenFormatting_ThenUsesMUnit() {
        XCTAssertEqual(TokenCountFormatters.compact(2_500_000), "2.5M")
    }

    func testBDD_GivenValueAtHundredMillion_WhenFormatting_ThenUsesYiUnit() {
        XCTAssertEqual(TokenCountFormatters.compact(120_000_000), "1.2亿")
    }
}
