import SwiftUI
import NolonResourceKit
import NolonUI

struct AddRepositorySheet: View {
    @Binding var isPresented: Bool
    @State private var viewModel: AddRepositoryViewModel

    init(
        isPresented: Binding<Bool>,
        settings: ProviderSettings,
        repositoryToEdit: RemoteRepository? = nil,
        onDirectoryCandidatesFound: @escaping (RemoteRepository, [GitRepository.SkillsDirectoryCandidate]) -> Void,
        onRepositorySaved: ((RemoteRepository) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        
        let vm = AddRepositoryViewModel(settings: settings, repositoryToEdit: repositoryToEdit)
        vm.onDirectoryCandidatesFound = onDirectoryCandidatesFound
        vm.onRepositorySaved = onRepositorySaved
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        NolonUI.RepositoryEditorSheetScaffoldView(
            isBlocking: viewModel.isAddingRepository
        ) {
            formContent
        } footer: {
            footerView
        }
        .onAppear {
            viewModel.onDismiss = {
                isPresented = false
            }
            // Check for pending URL on appear (handles @State caching issue)
            viewModel.checkPendingImportURL()
        }
    }

    // MARK: - Footer View
    
    private var footerView: some View {
        NolonUI.RepositoryEditorFooterView(
            data: .init(
                errorMessage: viewModel.validationError,
                primaryTitle: viewModel.isEditing ? "Save" : "Add",
                isPrimaryDisabled: !viewModel.canAddRepository || viewModel.isAddingRepository
            ),
            onCancel: { isPresented = false },
            onPrimary: { Task { await viewModel.saveRepository() } }
        )
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        NolonUI.RepositoryEditorFormContentView(
            templateOptions: viewModel.availableTemplates.map {
                .init(
                    id: $0.rawValue,
                    title: $0.displayName,
                    logoName: $0.logoName,
                    iconName: $0.iconName
                )
            },
            selectedTemplateID: Binding(
                get: { viewModel.selectedTemplate.rawValue },
                set: { rawValue in
                    if let template = RepositoryTemplate(rawValue: rawValue) {
                        viewModel.selectedTemplate = template
                    }
                }
            ),
            isTemplateSelectionDisabled: viewModel.isEditing,
            detailData: templateDetailData,
            gitURL: $viewModel.newGitURL,
            onPasteGitURL: {
                _ = viewModel.applyGitURL(NSPasteboard.general.string(forType: .string))
            },
            onTapSelectLocalFolder: { viewModel.selectLocalFolder() },
            onDropLocalFolderURLs: { items in
                viewModel.applyDroppedFolderURLs(items)
            }
        )
    }

    private var templateDetailData: RepositoryTemplateDetailData {
        let provider = RemoteRepository.detectProvider(from: viewModel.newGitURL) ?? .github
        return RepositoryTemplateDetailData(
            templateKind: templateKind(from: viewModel.selectedTemplate),
            clawdhubBaseURL: viewModel.selectedTemplate.defaultBaseURL,
            localFolderDisplayText: viewModel.newLocalPath,
            gitProviderDisplayName: provider.displayName,
            gitProviderLogoName: provider.logoName
        )
    }

    private func templateKind(from template: RepositoryTemplate) -> RepositoryEditorTemplateKind {
        switch template {
        case .clawdhub:
            return .clawdhub
        case .localFolder:
            return .localFolder
        case .git, .globalSkills:
            return .git
        }
    }
}
