import SwiftUI

struct SkillDetailSidebar: View {
    let viewModel: SkillDetailViewViewModel
    
    var body: some View {
        SkillDetailSidebarContainer {
            ScrollView {
                VStack(spacing: 32) {
                    SkillIdentityModule(
                        title: viewModel.viewData.title,
                        version: viewModel.viewData.version,
                        showsLocalBadge: viewModel.viewData.showsLocalBadge
                    )
                    .padding(.top, 32)

                    SkillInstallationSection(
                        mode: viewModel.viewData.mode,
                        providers: viewModel.viewData.providers,
                        providerInstallationStates: viewModel.viewData.providerInstallationStates,
                        onInstallProvider: viewModel.installProvider
                    )

                    if viewModel.viewData.showsFileNavigator {
                        SkillFileNavigator(
                            files: viewModel.viewData.files,
                            selectedFileID: viewModel.viewData.selectedFileID,
                            onSelectFile: viewModel.selectFile
                        )
                    }

                    SkillAboutSection(
                        description: viewModel.viewData.detailDescription,
                        metadataRows: viewModel.viewData.aboutMetadataRows
                    )

                    if viewModel.viewData.showsSyncSection {
                        SkillSyncSection(
                            isWorkflowLinked: viewModel.viewData.isWorkflowLinked,
                            currentProvider: viewModel.viewData.providers.first(where: { $0.id == viewModel.viewData.currentProviderID }),
                            onToggleWorkflow: viewModel.toggleWorkflow
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        } footer: {
            if viewModel.viewData.showsRevealInFinder {
                VStack(spacing: 0) {
                    Divider()
                        .background(DesignSystem.Colors.Component.border.opacity(0.3))

                    Button(action: viewModel.revealInFinder) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder")
                            Text(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.Component.controlFillSubtle)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.Colors.Component.border.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                }
                .background(DesignSystem.Colors.Background.elevated)
            }
        }
    }
}
