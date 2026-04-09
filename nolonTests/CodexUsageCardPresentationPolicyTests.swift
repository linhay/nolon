import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class CodexUsageCardPresentationPolicyTests: XCTestCase {
    func testBDD_GivenHealthyState_WhenMappingStatusKind_ThenReturnsHealthy() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .healthy)
        XCTAssertEqual(kind, .healthy)
    }

    func testBDD_GivenNeedsReauthState_WhenMappingStatusKind_ThenReturnsError() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .needsReauth)
        XCTAssertEqual(kind, .error)
    }

    func testBDD_GivenFailedState_WhenMappingStatusKind_ThenReturnsError() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .failed)
        XCTAssertEqual(kind, .error)
    }

    func testBDD_GivenPendingState_WhenMappingStatusKind_ThenReturnsPending() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .pending)
        XCTAssertEqual(kind, .pending)
    }

    func testBDD_GivenReauthWithLoginAction_WhenComputingLayout_ThenReturnsDualEqualWidth() {
        let layout = CodexUsageCardPresentationPolicy.actionLayout(needsReauth: true, hasLoginAction: true)
        XCTAssertEqual(layout, .dualEqualWidth)
    }

    func testBDD_GivenReauthWithoutLoginAction_WhenComputingLayout_ThenReturnsSingleFullWidth() {
        let layout = CodexUsageCardPresentationPolicy.actionLayout(needsReauth: true, hasLoginAction: false)
        XCTAssertEqual(layout, .singleFullWidth)
    }

    func testBDD_GivenNonReauthFailure_WhenComputingLayout_ThenReturnsSingleFullWidth() {
        let layout = CodexUsageCardPresentationPolicy.actionLayout(needsReauth: false, hasLoginAction: true)
        XCTAssertEqual(layout, .singleFullWidth)
    }
}
