import XCTest
import ProviderUsage
@testable import nolon

final class UsageMonitorServiceTests: XCTestCase {
    func testDefaultTokenAccountsFileURL_UsesNolonPathLayout() {
        let url = ProviderUsagePaths.defaultTokenAccountsFileURL()
        XCTAssertTrue(url.path.hasSuffix("/Nolon/token-accounts.json"))
    }
}
