import XCTest
import ProviderCatalog
@testable import nolon

final class ResourceDeleteTargetSheetStateTests: XCTestCase {
    func testBDD_GivenPreferredProviderIndex_WhenBuildExecutionPlan_ThenTargetsOnlyThatProvider() {
        let providers = [
            Self.makeProvider(id: "provider-a", name: "Provider A"),
            Self.makeProvider(id: "provider-b", name: "Provider B")
        ]

        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: 1,
            removeGlobalCache: false,
            providers: providers
        )

        XCTAssertEqual(plan.providerIDs, ["provider-b"])
        XCTAssertFalse(plan.removeGlobalCache)
        XCTAssertNil(plan.globalCachePathHint)
    }

    func testBDD_GivenDeleteAll_WhenBuildExecutionPlan_ThenTargetsAllProvidersAndGlobalCache() {
        let providers = [
            Self.makeProvider(id: "provider-a", name: "Provider A")
        ]

        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: nil,
            removeGlobalCache: true,
            providers: providers,
            globalCachePathHint: "/tmp/global/cache"
        )

        XCTAssertEqual(plan.providerIDs, ["provider-a"])
        XCTAssertTrue(plan.removeGlobalCache)
        XCTAssertEqual(plan.globalCachePathHint, "/tmp/global/cache")
    }

    func testBDD_GivenDeleteAllDisabled_WhenBuildExecutionPlan_ThenNoProviderAndNoGlobalCache() {
        let providers = [
            Self.makeProvider(id: "provider-a", name: "Provider A"),
            Self.makeProvider(id: "provider-b", name: "Provider B")
        ]

        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: nil,
            removeGlobalCache: false,
            providers: providers
        )

        XCTAssertTrue(plan.providerIDs.isEmpty)
        XCTAssertFalse(plan.removeGlobalCache)
        XCTAssertNil(plan.globalCachePathHint)
    }

    private static func makeProvider(id: String, name: String) -> Provider {
        Provider(
            id: id,
            name: name,
            defaultSkillsPath: "/tmp/\(id)/skills",
            workflowPath: "/tmp/\(id)/workflows",
            installMethod: .symlink,
            templateId: nil
        )
    }
}
