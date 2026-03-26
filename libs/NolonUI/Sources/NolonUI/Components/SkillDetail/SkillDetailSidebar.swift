import SwiftUI
import ProviderCatalog
import NolonResourceKit

struct SkillDetailSidebar: View {
    @Bindable var viewModel: SkillDetailViewModel
    let providers: [Provider]
    let currentProvider: Provider?
    
    var body: some View {
        SkillDetailSidebarContainer {
            ScrollView {
                VStack(spacing: 32) {
                    SkillIdentityModule(
                        title: viewModel.title,
                        version: viewModel.version,
                        showsLocalBadge: viewModel.showsLocalBadge
                    )
                    .padding(.top, 32)

                    SkillInstallationSection(viewModel: viewModel, providers: providers)

                    if viewModel.showsFileNavigator {
                        SkillFileNavigator(viewModel: viewModel)
                    }

                    SkillAboutSection(
                        description: viewModel.detailDescription,
                        metadataRows: viewModel.aboutMetadataRows
                    )

                    if viewModel.showsSyncSection {
                        SkillSyncSection(viewModel: viewModel, currentProvider: currentProvider)
                    }
                }
                .padding(.bottom, 24)
            }
        } footer: {
            if viewModel.showsRevealInFinder {
                VStack(spacing: 0) {
                    Divider()
                        .background(DesignSystem.Colors.Component.border.opacity(0.3))

                    Button(action: { viewModel.revealInFinder() }) {
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
