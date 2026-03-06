import XCTest
import ProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ResourceDeletionCoordinatorTests: XCTestCase {
    private var fixture: TestFixture!

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
    }

    func testBDD_GivenSingleProvider_WhenDeleteProviderTarget_ThenOnlyOneAttemptAndSuccess() async {
        let providerA = fixture.createProvider(name: "A", method: .symlink)
        let providerB = fixture.createProvider(name: "B", method: .symlink)
        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: 0,
            removeGlobalCache: false,
            providers: [providerA, providerB]
        )
        let providerTargets = plan.resolveProviderTargets(from: [providerA, providerB])

        let coordinator = ResourceDeletionCoordinator(
            uninstallAction: { _, _, _ in
            },
            removeGlobalAction: { _, _, _ in false }
        )

        let result = await coordinator.execute(
            resourceSlug: "demo-skill",
            resourceType: .skill,
            providerTargets: providerTargets,
            removeGlobalCache: plan.removeGlobalCache,
            globalCachePathHint: plan.globalCachePathHint
        )

        XCTAssertEqual(result.attemptedCount, 1)
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failures.count, 0)
        XCTAssertFalse(result.removedGlobalCache)
    }

    func testBDD_GivenAllProviders_WhenDeleteAllTarget_ThenGlobalCacheAlsoRemoved() async {
        let providerA = fixture.createProvider(name: "A", method: .symlink)
        let providerB = fixture.createProvider(name: "B", method: .symlink)
        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: nil,
            removeGlobalCache: true,
            providers: [providerA, providerB]
        )
        let providerTargets = plan.resolveProviderTargets(from: [providerA, providerB])

        let coordinator = ResourceDeletionCoordinator(
            uninstallAction: { _, _, _ in
            },
            removeGlobalAction: { _, _, _ in
                return true
            }
        )

        let result = await coordinator.execute(
            resourceSlug: "demo-workflow",
            resourceType: .workflow,
            providerTargets: providerTargets,
            removeGlobalCache: plan.removeGlobalCache,
            globalCachePathHint: plan.globalCachePathHint
        )

        XCTAssertEqual(result.attemptedCount, 2)
        XCTAssertEqual(result.successCount, 2)
        XCTAssertEqual(result.failures.count, 0)
        XCTAssertTrue(result.removedGlobalCache)
    }

    func testBDD_GivenPartialFailures_WhenDeleteAllTarget_ThenContinueAndCollectFailures() async {
        let providerA = fixture.createProvider(name: "A", method: .symlink)
        let providerB = fixture.createProvider(name: "B", method: .symlink)
        let providerC = fixture.createProvider(name: "C", method: .symlink)
        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: nil,
            removeGlobalCache: true,
            providers: [providerA, providerB, providerC]
        )
        let providerTargets = plan.resolveProviderTargets(from: [providerA, providerB, providerC])

        let coordinator = ResourceDeletionCoordinator(
            uninstallAction: { _, _, _ in
            },
            removeGlobalAction: { _, _, _ in
                throw NSError(domain: "ResourceDeletionCoordinatorTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "global remove failed"])
            }
        )

        let result = await coordinator.execute(
            resourceSlug: "demo-mcp",
            resourceType: .mcp,
            providerTargets: providerTargets,
            removeGlobalCache: plan.removeGlobalCache,
            globalCachePathHint: plan.globalCachePathHint
        )

        XCTAssertEqual(result.attemptedCount, 3)
        XCTAssertEqual(result.successCount, 3)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.targetName, "Global Cache")
    }
}
