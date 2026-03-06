import XCTest
import ProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ResourceDeletionExecutionPlanTests: XCTestCase {
    private var fixture: TestFixture!

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
    }

    func testBDD_GivenProviderTarget_WhenBuildPlan_ThenIncludeOnlyMatchingProviderID() {
        let providerA = fixture.createProvider(name: "A", method: .symlink)
        let providerB = fixture.createProvider(name: "B", method: .copy)

        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: 1,
            removeGlobalCache: false,
            providers: [providerA, providerB]
        )

        XCTAssertEqual(plan.providerIDs, [providerB.id])
        XCTAssertFalse(plan.removeGlobalCache)
        XCTAssertNil(plan.globalCachePathHint)
    }

    func testBDD_GivenDeleteAllTarget_WhenBuildPlan_ThenIncludeEveryProviderAndGlobalCacheFlag() {
        let providerA = fixture.createProvider(name: "A", method: .symlink)
        let providerB = fixture.createProvider(name: "B", method: .copy)

        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: nil,
            removeGlobalCache: true,
            providers: [providerA, providerB]
        )

        XCTAssertEqual(plan.providerIDs, [providerA.id, providerB.id])
        XCTAssertTrue(plan.removeGlobalCache)
        XCTAssertNil(plan.globalCachePathHint)
    }

    func testBDD_GivenDeleteAllTargetWithPathHint_WhenBuildPlan_ThenRetainGlobalCachePathHint() {
        let provider = fixture.createProvider(name: "A", method: .symlink)

        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: nil,
            removeGlobalCache: true,
            providers: [provider],
            globalCachePathHint: "/tmp/.nolon/skills/gemini"
        )

        XCTAssertEqual(plan.providerIDs, [provider.id])
        XCTAssertTrue(plan.removeGlobalCache)
        XCTAssertEqual(plan.globalCachePathHint, "/tmp/.nolon/skills/gemini")
    }
}
