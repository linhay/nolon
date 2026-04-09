import XCTest
@testable import nolon

final class TextNormalizationSupportTests: XCTestCase {
    func testBDD_GivenWhitespaceWrappedString_WhenTrimmed_ThenReturnsNormalizedValue() {
        XCTAssertEqual(TextNormalizationSupport.trimmed("  hello  "), "hello")
    }

    func testBDD_GivenBlankString_WhenTrimmed_ThenReturnsNil() {
        XCTAssertNil(TextNormalizationSupport.trimmed(" \n\t "))
    }

    func testBDD_GivenCandidateValues_WhenResolvingFirstNonEmpty_ThenSkipsBlankEntries() {
        XCTAssertEqual(
            TextNormalizationSupport.firstNonEmpty(nil, "  ", "\nfoo  ", "bar"),
            "foo"
        )
    }

    func testBDD_GivenMixedValues_WhenJoiningNonEmpty_ThenOmitsBlankItems() {
        XCTAssertEqual(
            TextNormalizationSupport.joinedNonEmpty([nil, "  alpha ", "\n", "beta  "]),
            "alpha • beta"
        )
    }
}
