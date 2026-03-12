import Foundation
import Testing
@testable import nolon

struct NolonAccountsCodexIDResolverTests {
    @Test("BDD: Given direct UUID id when resolving codex account id then returns UUID")
    func testBDD_GivenDirectUUIDID_WhenResolvingCodexAccountID_ThenReturnsUUID() throws {
        let expected = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        #expect(NolonAccountsViewModel.resolveCodexAccountID(from: expected.uuidString) == expected)
    }

    @Test("BDD: Given codex prefixed id when resolving codex account id then returns UUID suffix")
    func testBDD_GivenCodexPrefixedID_WhenResolvingCodexAccountID_ThenReturnsUUIDSuffix() throws {
        let expected = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(NolonAccountsViewModel.resolveCodexAccountID(from: "codex.\(expected.uuidString)") == expected)
    }

    @Test("BDD: Given non UUID codex id when resolving codex account id then returns nil")
    func testBDD_GivenNonUUIDCodexID_WhenResolvingCodexAccountID_ThenReturnsNil() {
        #expect(NolonAccountsViewModel.resolveCodexAccountID(from: "codex.default") == nil)
    }
}
