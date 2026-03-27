import SwiftUI
import NolonUIFoundation

public struct ProviderIdentityAndPathsFormSections: View {
    @Binding var name: String
    let nameSection: ProviderNameSectionData
    let vendorInfo: ProviderLabeledValueData?
    let projectFolderData: ProviderProjectFolderSectionData
    let resolvedPathsTitle: String
    let resolvedPathItems: [ProviderResolvedPathItemData]
    let onChooseProjectFolder: () -> Void

    public init(
        name: Binding<String>,
        nameSection: ProviderNameSectionData,
        vendorInfo: ProviderLabeledValueData? = nil,
        projectFolderData: ProviderProjectFolderSectionData,
        resolvedPathsTitle: String = NSLocalizedString(
            "add_provider.resolved_paths_label",
            value: "Resolved Paths",
            comment: "Resolved paths section header"
        ),
        resolvedPathItems: [ProviderResolvedPathItemData],
        onChooseProjectFolder: @escaping () -> Void
    ) {
        self._name = name
        self.nameSection = nameSection
        self.vendorInfo = vendorInfo
        self.projectFolderData = projectFolderData
        self.resolvedPathsTitle = resolvedPathsTitle
        self.resolvedPathItems = resolvedPathItems
        self.onChooseProjectFolder = onChooseProjectFolder
    }

    public var body: some View {
        Section {
            TextField(nameSection.placeholder, text: $name)
        } header: {
            Text(nameSection.title)
        }

        if let vendorInfo {
            Section {
                LabeledContent(vendorInfo.label) {
                    Text(vendorInfo.value)
                }
            }
        }

        ProviderProjectFolderSection(
            data: projectFolderData,
            onChooseProjectFolder: onChooseProjectFolder
        )

        ProviderResolvedPathsSection(
            title: resolvedPathsTitle,
            items: resolvedPathItems
        )
    }
}
