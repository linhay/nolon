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
            items: viewModel.sidebarItems,
            selectedID: $viewModel.selectedCategoryID,
            onClose: { dismiss() }
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
                workspaceData: .init(
                    path: viewModel.settingsStore.workspacePath
                ),
                onboardingActionData: .onboardingRerun(),
                onTapOnboardingAction: { viewModel.showingOnboardingResetConfirm = true }
            )
            .confirmationAlert(
                data: viewModel.onboardingResetConfirmationData,
                isPresented: $viewModel.showingOnboardingResetConfirm,
                onConfirm: { viewModel.confirmOnboardingReset() },
                onCancel: {}
            )
        case .display:
            NolonUI.DisplaySettingsContentView(
                data: viewModel.displayData,
                onSelectAppearance: { viewModel.selectAppearance(id: $0) },
                onSelectLanguage: { viewModel.selectLanguage(id: $0) }
            )
            .onAppear {
                viewModel.normalizeLanguageIfNeeded()
            }
        case .advanced:
            NolonUI.AdvancedSettingsContentView(
                skillLockData: viewModel.skillLockSectionData,
                overwriteExisting: $viewModel.overwriteExisting,
                isRebuildingSkillLock: viewModel.isRebuildingSkillLock,
                onTapRebuildSkillLock: { viewModel.showingRebuildConfirmation = true },
                updatesActionData: viewModel.updatesActionData,
                onTapUpdates: { viewModel.showingUpdatesSheet = true }
            )
            .confirmationAlert(
                data: viewModel.rebuildSkillLockConfirmationData,
                isPresented: $viewModel.showingRebuildConfirmation,
                onConfirm: {
                    Task { await viewModel.rebuildSkillLock() }
                },
                onCancel: {}
            )
            .sheet(isPresented: $viewModel.showingUpdatesSheet) {
                UpdatesView()
            }
            .task {
                await viewModel.refreshUpdateCount()
            }
        case .about:
            NolonUI.AboutSettingsSectionView(data: viewModel.aboutSettingsData) {
                nolonApp.updaterController?.updater.checkForUpdates()
            }
        }
    }
}

#Preview {
    AppSettingsView()
}
