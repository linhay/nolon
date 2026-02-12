import XCTest
@testable import nolon

final class UsageMonitorServiceTests: XCTestCase {
    func testDefaultTokenAccountsFileURL_UsesNolonPathLayout() {
        let url = UsageMonitorService.defaultTokenAccountsFileURL()
        XCTAssertTrue(url.path.hasSuffix("/Nolon/token-accounts.json"))
    }
}
