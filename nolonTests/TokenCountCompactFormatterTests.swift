import XCTest
@testable import nolon

final class TokenCountCompactFormatterTests: XCTestCase {
    func testBDD_GivenValueBelowOneThousand_WhenFormatting_ThenReturnsRawNumber() {
        XCTAssertEqual(TokenCountCompactFormatter.format(999), "999")
    }

    func testBDD_GivenValueInThousands_WhenFormatting_ThenUsesKUnit() {
        XCTAssertEqual(TokenCountCompactFormatter.format(1_500), "1.5K")
    }

    func testBDD_GivenValueInMillions_WhenFormatting_ThenUsesMUnit() {
        XCTAssertEqual(TokenCountCompactFormatter.format(2_500_000), "2.5M")
    }

    func testBDD_GivenValueAtHundredMillion_WhenFormatting_ThenUsesYiUnit() {
        XCTAssertEqual(TokenCountCompactFormatter.format(120_000_000), "1.2亿")
    }
}
