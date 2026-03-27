import XCTest
import NolonUIFoundation
@testable import nolon

final class ProviderQuotaSectionViewDataTests: XCTestCase {
    func testBDD_GivenLoginAndSyncDates_WhenBuildingSyncText_ThenIncludesBothSegments() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let loginAt = now.addingTimeInterval(-3600)
        let syncedAt = now.addingTimeInterval(-120)

        let text = ProviderQuotaSectionBuilders.syncText(loginAt: loginAt, syncedAt: syncedAt, now: now)

        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("LoggedIn") == true)
        XCTAssertTrue(text?.contains("Synced") == true)
    }

    func testBDD_GivenPastResetTime_WhenBuildingResetText_ThenReturnsNow() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let resetsAt = now.addingTimeInterval(-1)

        let text = ProviderQuotaSectionBuilders.resetText(resetsAt: resetsAt, now: now)

        XCTAssertEqual(text, "now")
    }

    func testBDD_GivenFutureResetTime_WhenBuildingResetText_ThenIncludesLeftSuffix() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let resetsAt = now.addingTimeInterval(7200)

        let text = ProviderQuotaSectionBuilders.resetText(resetsAt: resetsAt, now: now)

        XCTAssertTrue(text.contains("left"))
    }
}
