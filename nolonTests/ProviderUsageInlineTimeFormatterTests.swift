import XCTest
import NolonUIFoundation
@testable import nolon

@MainActor
final class ProviderUsageInlineTimeFormatterTests: XCTestCase {
    func testBDD_GivenFixedDate_WhenFormattingLoginTimestamp_ThenUsesShortMonthDayAndTime() throws {
        let date = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 14, minute: 37, second: 58)

        let text = ProviderUsageInlineTimeFormatters.loginTimestamp(
            date,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "03/03 14:37")
    }

    func testBDD_GivenSyncWithin59Seconds_WhenFormattingSyncDisplay_ThenUsesJustNowState() throws {
        let now = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 0, second: 59)
        let syncAt = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 0, second: 0)

        let display = ProviderUsageInlineTimeFormatters.syncDisplay(
            since: syncAt,
            now: now,
            isChinese: true,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(display, .justNow)
    }

    func testBDD_GivenSyncWithinHour_WhenFormattingSyncDisplay_ThenUsesMinuteRelativeText() throws {
        let now = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 8, second: 40)
        let syncAt = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 0, second: 0)

        let display = ProviderUsageInlineTimeFormatters.syncDisplay(
            since: syncAt,
            now: now,
            isChinese: false,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(display, .relative("8m"))
    }

    func testBDD_GivenSyncWithinDay_WhenFormattingSyncDisplay_ThenUsesHourMinuteRelativeText() throws {
        let now = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 2, minute: 5, second: 0)
        let syncAt = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 0, second: 0)

        let display = ProviderUsageInlineTimeFormatters.syncDisplay(
            since: syncAt,
            now: now,
            isChinese: true,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(display, .relative("2小时5分"))
    }

    func testBDD_GivenSyncOverOneDay_WhenFormattingSyncDisplay_ThenUsesAbsoluteTimestamp() throws {
        let now = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 15, minute: 0, second: 0)
        let syncAt = try makeUTCDate(year: 2026, month: 3, day: 2, hour: 11, minute: 30, second: 0)

        let display = ProviderUsageInlineTimeFormatters.syncDisplay(
            since: syncAt,
            now: now,
            isChinese: false,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(display, .absolute("03/02 11:30"))
    }

    func testBDD_GivenFutureSyncTime_WhenFormattingSyncDisplay_ThenClampsToJustNow() throws {
        let now = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 0, second: 0)
        let syncAt = try makeUTCDate(year: 2026, month: 3, day: 3, hour: 0, minute: 5, second: 0)

        let display = ProviderUsageInlineTimeFormatters.syncDisplay(
            since: syncAt,
            now: now,
            isChinese: true,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(display, .justNow)
    }

    func testBDD_GivenBothSegments_WhenJoiningInlineTimeLine_ThenUsesMiddleDotSeparator() {
        let line = ProviderUsageInlineTimeFormatters.joinInlineTimeLine(
            loginSegment: "登录 03/03 14:37",
            syncSegment: "刚刚同步"
        )

        XCTAssertEqual(line, "登录 03/03 14:37 · 刚刚同步")
    }

    func testBDD_GivenOneOrNoSegment_WhenJoiningInlineTimeLine_ThenOmitsSeparator() {
        XCTAssertEqual(
            ProviderUsageInlineTimeFormatters.joinInlineTimeLine(
                loginSegment: "登录 03/03 14:37",
                syncSegment: nil
            ),
            "登录 03/03 14:37"
        )
        XCTAssertEqual(
            ProviderUsageInlineTimeFormatters.joinInlineTimeLine(
                loginSegment: nil,
                syncSegment: "同步于 8m 前"
            ),
            "同步于 8m 前"
        )
        XCTAssertNil(ProviderUsageInlineTimeFormatters.joinInlineTimeLine(loginSegment: nil, syncSegment: nil))
    }

    private func makeUTCDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int
    ) throws -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let date = components.date else {
            throw NSError(domain: "ProviderUsageInlineTimeFormatterTests", code: 1)
        }
        return date
    }
}
