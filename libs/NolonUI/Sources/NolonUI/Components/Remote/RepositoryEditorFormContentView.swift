import SwiftUI
import NolonUIFoundation

public struct RepositoryEditorFormContentView: View {
    let templateOptions: [RepositoryTemplateOptionItem]
    @Binding var selectedTemplateID: String
    let isTemplateSelectionDisabled: Bool
    let detailData: RepositoryTemplateDetailData
    @Binding var gitURL: String
    let onPasteGitURL: () -> Void
    let onTapSelectLocalFolder: () -> Void
    let onDropLocalFolderURLs: ([URL]) -> Bool

    public init(
        templateOptions: [RepositoryTemplateOptionItem],
        selectedTemplateID: Binding<String>,
        isTemplateSelectionDisabled: Bool,
        detailData: RepositoryTemplateDetailData,
        gitURL: Binding<String>,
        onPasteGitURL: @escaping () -> Void,
        onTapSelectLocalFolder: @escaping () -> Void,
        onDropLocalFolderURLs: @escaping ([URL]) -> Bool
    ) {
        self.templateOptions = templateOptions
        self._selectedTemplateID = selectedTemplateID
        self.isTemplateSelectionDisabled = isTemplateSelectionDisabled
        self.detailData = detailData
        self._gitURL = gitURL
        self.onPasteGitURL = onPasteGitURL
        self.onTapSelectLocalFolder = onTapSelectLocalFolder
        self.onDropLocalFolderURLs = onDropLocalFolderURLs
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            RepositoryTemplateSelectionView(
                options: templateOptions,
                selectedID: $selectedTemplateID,
                disabled: isTemplateSelectionDisabled
            )

            templateDetailSection
        }
    }

    @ViewBuilder
    private var templateDetailSection: some View {
        switch detailData.templateKind {
        case .clawdhub:
            FormSectionBlockView(title: detailData.detailsSectionTitle) {
                RepositoryReadOnlyFieldView(value: detailData.clawdhubBaseURL)
                FormSecondaryHintText(detailData.clawdhubHint)
            }
        case .localFolder:
            FormSectionBlockView(title: detailData.skillsFolderSectionTitle) {
                FolderDropPickerCardView(
                    displayText: detailData.localFolderDisplayText,
                    placeholderText: detailData.localFolderPlaceholderText,
                    hintText: detailData.localFolderHintText,
                    onTap: onTapSelectLocalFolder,
                    onDropURLs: onDropLocalFolderURLs
                )
                FormSecondaryHintText(detailData.localFolderSecondaryHint)
            }
        case .git:
            VStack(alignment: .leading, spacing: 20) {
                FormSectionBlockView(title: detailData.gitRepositorySectionTitle) {
                    RepositoryGitURLInputRowView(
                        gitURL: $gitURL,
                        providerDisplayName: detailData.gitProviderDisplayName,
                        providerLogoName: detailData.gitProviderLogoName,
                        onPaste: onPasteGitURL
                    )

                    FormSecondaryHintText(detailData.gitSupportHint)
                }

                FormSecondaryHintText(detailData.gitSyncHint)
            }
        }
    }
}
