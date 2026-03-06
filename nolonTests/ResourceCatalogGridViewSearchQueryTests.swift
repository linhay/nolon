import XCTest
@testable import nolon

final class ResourceCatalogGridViewSearchQueryTests: XCTestCase {
    func testResolveSearchQuery_UsesDebouncedValueWhenAvailable() {
        let query = ResourceCatalogGridView.resolveSearchQuery(
            isClawdhub: true,
            debouncedSearchText: "gemini ",
            searchText: "ignored"
        )

        XCTAssertEqual(query, "gemini")
    }

    func testResolveSearchQuery_FallsBackToSearchTextWhenDebouncedIsEmpty() {
        let query = ResourceCatalogGridView.resolveSearchQuery(
            isClawdhub: true,
            debouncedSearchText: "  ",
            searchText: " gemini "
        )

        XCTAssertEqual(query, "gemini")
    }

    func testResolveSearchQuery_ReturnsEmptyForNonClawdhubRepository() {
        let query = ResourceCatalogGridView.resolveSearchQuery(
            isClawdhub: false,
            debouncedSearchText: "gemini",
            searchText: "gemini"
        )

        XCTAssertEqual(query, "")
    }
}
