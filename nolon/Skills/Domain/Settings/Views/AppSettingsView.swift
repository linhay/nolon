import Foundation
import SwiftUI
import Sparkle
import NolonResourceKit
import NolonUI
import NolonUIFoundation

struct AppSettingsView: View {
    @State private var viewModel = AppSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel

        NolonUI.SettingsSheetScaffoldView(
            selectedID: $viewModel.selectedCategoryID,
            config: .init(
                items: viewModel.sidebarItems,
                onClose: { dismiss() }
            )
        ) {
            contentForSelectedCategory
        }
    }

    @ViewBuilder
    private var contentForSelectedCategory: some View {
        @Bindable var viewModel = viewModel

        switch viewModel.selectedCategory {
        case .general:
            NolonUI.GeneralSettingsContentView(
                config: .init(
                    workspaceData: .init(
                        path: viewModel.settingsStore.workspacePath
                    ),
                    onboardingActionData: .onboardingRerun(),
                    onTapOnboardingAction: { viewModel.showingOnboardingResetConfirm = true }
                )
            )
            .confirmationAlert(
                data: viewModel.onboardingResetConfirmationData,
                isPresented: $viewModel.showingOnboardingResetConfirm,
                onConfirm: { viewModel.confirmOnboardingReset() },
                onCancel: {}
            )
        case .display:
            NolonUI.DisplaySettingsContentView(
                config: .init(
                    data: viewModel.displayData,
                    onSelectAppearance: { viewModel.selectAppearance(id: $0) },
                    onSelectLanguage: { viewModel.selectLanguage(id: $0) }
                )
            )
            .onAppear {
                viewModel.normalizeLanguageIfNeeded()
            }
        case .advanced:
            VStack(alignment: .leading, spacing: 24) {
                NolonUI.AdvancedSettingsContentView(
                    config: .init(
                        skillLockData: viewModel.skillLockSectionData,
                        overwriteExisting: $viewModel.overwriteExisting,
                        isRebuildingSkillLock: viewModel.isRebuildingSkillLock,
                        onTapRebuildSkillLock: { viewModel.showingRebuildConfirmation = true },
                        updatesActionData: viewModel.updatesActionData,
                        onTapUpdates: { viewModel.showingUpdatesSheet = true }
                    )
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        NSLocalizedString(
                            "settings.advanced.updates.channel.title",
                            value: "Update Channel",
                            comment: "Update channel section title"
                        )
                    )
                    .font(.headline)

                    NolonUI.SettingsActionCardView(
                        data: viewModel.updateChannelActionData,
                        onTap: { viewModel.openUpdateChannelDialog() }
                    )

                    Text(
                        NSLocalizedString(
                            "settings.advanced.updates.channel.description",
                            value: "Switch between stable and beta updates. Beta may include unfinished changes.",
                            comment: "Update channel description"
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .confirmationAlert(
                data: viewModel.rebuildSkillLockConfirmationData,
                isPresented: $viewModel.showingRebuildConfirmation,
                onConfirm: {
                    Task { await viewModel.rebuildSkillLock() }
                },
                onCancel: {}
            )
            .confirmationDialog(
                NSLocalizedString(
                    "settings.advanced.updates.channel.dialog_title",
                    value: "Choose update channel",
                    comment: "Update channel picker dialog title"
                ),
                isPresented: $viewModel.showingUpdateChannelDialog,
                titleVisibility: .visible
            ) {
                ForEach(AppUpdateChannel.allCases) { channel in
                    Button(channel.displayName) {
                        viewModel.selectUpdateChannel(id: channel.rawValue)
                    }
                }
                Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {}
            }
            .sheet(isPresented: $viewModel.showingUpdatesSheet) {
                UpdatesView()
            }
            .task {
                await viewModel.refreshUpdateCount()
            }
        case .about:
            NolonUI.AboutSettingsSectionView(
                config: .init(
                    data: viewModel.aboutSettingsData,
                    onCheckUpdates: { nolonApp.updaterController?.updater.checkForUpdates() }
                )
            )
        }
    }
}

#Preview {
    AppSettingsView()
}
