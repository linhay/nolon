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

        let coordinator = ResourceDeletionCoordinator(
            uninstallAction: { _, _, _ in
            },
            removeGlobalAction: { _, _ in false }
        )

        let result = await coordinator.execute(
            resourceSlug: "demo-skill",
            resourceType: .skill,
            target: .provider(providerA.id),
            providers: [providerA, providerB]
        )

        XCTAssertEqual(result.attemptedCount, 1)
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failures.count, 0)
        XCTAssertFalse(result.removedGlobalCache)
    }

    func testBDD_GivenAllProviders_WhenDeleteAllTarget_ThenGlobalCacheAlsoRemoved() async {
        let providerA = fixture.createProvider(name: "A", method: .symlink)
        let providerB = fixture.createProvider(name: "B", method: .symlink)

        let coordinator = ResourceDeletionCoordinator(
            uninstallAction: { _, _, _ in
            },
            removeGlobalAction: { _, _ in
                return true
            }
        )

        let result = await coordinator.execute(
            resourceSlug: "demo-workflow",
            resourceType: .workflow,
            target: .allProvidersAndGlobalCache,
            providers: [providerA, providerB]
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

        let coordinator = ResourceDeletionCoordinator(
            uninstallAction: { _, _, _ in
            },
            removeGlobalAction: { _, _ in
                throw NSError(domain: "ResourceDeletionCoordinatorTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "global remove failed"])
            }
        )

        let result = await coordinator.execute(
            resourceSlug: "demo-mcp",
            resourceType: .mcp,
            target: .allProvidersAndGlobalCache,
            providers: [providerA, providerB, providerC]
        )

        XCTAssertEqual(result.attemptedCount, 3)
        XCTAssertEqual(result.successCount, 3)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.targetName, "Global Cache")
    }
}
