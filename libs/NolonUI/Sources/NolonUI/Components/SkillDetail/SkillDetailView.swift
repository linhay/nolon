import SwiftUI
import Observation

public struct SkillDetailView: View {
    @Bindable private var viewModel: SkillDetailViewViewModel

    public init(viewModel: SkillDetailViewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        SkillDetailScaffold(onClose: viewModel.close) {
            SkillDetailSidebar(viewModel: viewModel)
        } content: {
            SkillDetailContent(viewModel: viewModel)
        }
    }
}

#Preview("Skill Detail / Remote Catalog") {
    SkillDetailView(
        viewModel: SkillDetailViewViewModel(
            viewData: .init(
                mode: .remoteCatalog,
                contentMode: .remoteOverview,
                title: "SectionUI",
                detailDescription: "Master skill for SectionUI collection layout and data-driven rendering.",
                version: "1.4.2",
                contentTitle: "Overview",
                showsLocalBadge: false,
                showsFileNavigator: false,
                showsRevealInFinder: false,
                showsSyncSection: false,
                isWorkflowLinked: false,
                files: [],
                selectedFileID: nil,
                aboutMetadataRows: [],
                remoteStats: .init(stars: 860, downloads: 12400),
                remoteChangelog: "### 1.4.2\n- Improved list performance\n- Added better markdown rendering",
                remoteSummary: nil,
                providers: [
                    .init(id: "codex", name: "Codex", logoName: "codex"),
                    .init(id: "claude", name: "Claude", logoName: "claude")
                ],
                currentProviderID: "codex",
                providerInstallationStates: ["codex": false, "claude": true]
            ),
            onClose: {},
            onSelectFile: { _ in },
            onInstallProvider: { _ in },
            onToggleWorkflow: { _ in },
            onRevealInFinder: {},
            onOpenMarkdownLink: { _ in .handled }
        )
    )
    .frame(width: 1120, height: 760)
}

#Preview("Skill Detail / Local Installed") {
    SkillDetailView(
        viewModel: SkillDetailViewViewModel(
            viewData: .init(
                mode: .local,
                contentMode: .fileBrowser,
                title: "SectionUI",
                detailDescription: "Use when building complex UICollectionView layouts.",
                version: "1.4.2",
                contentTitle: "SKILL.md",
                showsLocalBadge: false,
                showsFileNavigator: true,
                showsRevealInFinder: true,
                showsSyncSection: true,
                isWorkflowLinked: true,
                files: [
                    .init(
                        id: "/tmp/sectionui/SKILL.md",
                        name: "SKILL.md",
                        type: .markdown,
                        content: """
                        # SectionUI

                        Use when building complex UICollectionView layouts.
                        """
                    ),
                    .init(
                        id: "/tmp/sectionui/scripts/install.sh",
                        name: "scripts/install.sh",
                        type: .code,
                        content: "echo install sectionui"
                    )
                ],
                selectedFileID: "/tmp/sectionui/SKILL.md",
                aboutMetadataRows: [
                    .init(id: "path", label: "Path", value: "/tmp/sectionui"),
                    .init(id: "updated", label: "Updated", value: "Mar 26, 2026")
                ],
                remoteStats: nil,
                remoteChangelog: nil,
                remoteSummary: nil,
                providers: [
                    .init(id: "codex", name: "Codex", logoName: "codex"),
                    .init(id: "claude", name: "Claude", logoName: "claude")
                ],
                currentProviderID: "codex",
                providerInstallationStates: ["codex": true, "claude": false]
            ),
            onClose: {},
            onSelectFile: { _ in },
            onInstallProvider: { _ in },
            onToggleWorkflow: { _ in },
            onRevealInFinder: {},
            onOpenMarkdownLink: { _ in .handled }
        )
    )
    .frame(width: 1120, height: 760)
}
