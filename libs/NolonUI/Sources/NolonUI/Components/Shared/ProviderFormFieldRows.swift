import SwiftUI

public struct ProviderProjectFolderPickerRow: View {
    let displayPath: String
    let emptyPlaceholder: String
    let chooseButtonTitle: String
    let onChoose: () -> Void

    public init(
        displayPath: String,
        emptyPlaceholder: String,
        chooseButtonTitle: String,
        onChoose: @escaping () -> Void
    ) {
        self.displayPath = displayPath
        self.emptyPlaceholder = emptyPlaceholder
        self.chooseButtonTitle = chooseButtonTitle
        self.onChoose = onChoose
    }

    public var body: some View {
        HStack {
            Text(displayPath.isEmpty ? emptyPlaceholder : displayPath)
                .foregroundStyle(displayPath.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(chooseButtonTitle) {
                onChoose()
            }
            .dsSecondaryButton()
        }
    }
}

public struct ProviderResolvedPathRow: View {
    let label: String
    let path: String
    let emptyPlaceholder: String

    public init(
        label: String,
        path: String,
        emptyPlaceholder: String
    ) {
        self.label = label
        self.path = path
        self.emptyPlaceholder = emptyPlaceholder
    }

    public var body: some View {
        LabeledContent(label) {
            Text(path.isEmpty ? emptyPlaceholder : path)
                .foregroundStyle(path.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
