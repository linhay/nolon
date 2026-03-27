import SwiftUI
import NolonUIFoundation

public struct ProviderProjectFolderSection: View {
    let data: ProviderProjectFolderSectionData
    let onChooseProjectFolder: () -> Void

    public init(
        data: ProviderProjectFolderSectionData,
        onChooseProjectFolder: @escaping () -> Void
    ) {
        self.data = data
        self.onChooseProjectFolder = onChooseProjectFolder
    }

    public var body: some View {
        Section {
            switch data.mode {
            case .project:
                ProviderProjectFolderPickerRow(
                    displayPath: data.displayPath,
                    emptyPlaceholder: data.emptyPlaceholder,
                    chooseButtonTitle: data.chooseButtonTitle,
                    onChoose: onChooseProjectFolder
                )
            case .vendorLocked:
                Text(data.vendorLockedDescription)
                    .dsSecondaryText(font: .callout)
            }
        } header: {
            Text(data.sectionTitle)
        }
    }
}

public struct ProviderResolvedPathsSection: View {
    let title: String
    let items: [ProviderResolvedPathItemData]

    public init(
        title: String,
        items: [ProviderResolvedPathItemData]
    ) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    ProviderResolvedPathRow(
                        label: item.label,
                        path: item.path,
                        emptyPlaceholder: item.emptyPlaceholder
                    )
                }
            }
        } header: {
            Text(title)
        }
    }
}

