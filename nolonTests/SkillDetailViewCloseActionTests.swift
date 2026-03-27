import XCTest
import SwiftUI
import NolonUI
import NolonUIFoundation
@testable import nolon

final class SkillDetailViewCloseActionTests: XCTestCase {
    func testBDD_GivenSkillDetailViewModel_WhenClose_ThenRunsProvidedCloseAction() {
        var customCloseCount = 0

        let viewModel = SkillDetailViewViewModel(
            viewData: Self.makeViewData(),
            onClose: {
                customCloseCount += 1
            },
            onSelectFile: { _ in },
            onInstallProvider: { _ in },
            onToggleWorkflow: { _ in },
            onRevealInFinder: {},
            onOpenMarkdownLink: { _ in .handled }
        )
        viewModel.close()

        XCTAssertEqual(customCloseCount, 1)
    }

    private static func makeViewData() -> SkillDetailViewData {
        SkillDetailViewData(
            mode: .local,
            contentMode: .fileBrowser,
            title: "Test Skill",
            detailDescription: "Test",
            version: "1.0.0",
            contentTitle: "README",
            showsLocalBadge: true,
            showsFileNavigator: true,
            showsRevealInFinder: false,
            showsSyncSection: false,
            isWorkflowLinked: false,
            files: [],
            selectedFileID: nil,
            aboutMetadataRows: [],
            remoteStats: nil,
            remoteChangelog: nil,
            remoteSummary: nil,
            providers: [],
            currentProviderID: nil,
            providerInstallationStates: [:]
        )
    }
}
