import SwiftUI

public struct ActionUnavailableStateView: View {
    let title: String
    let systemImage: String
    let description: String?
    let actionTitle: String
    let onAction: () -> Void

    public init(
        title: String,
        systemImage: String,
        description: String? = nil,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateTitle()
            } icon: {
                Image(systemName: systemImage)
                    .dsEmptyStateIcon()
            }
        } description: {
            if let description, !description.isEmpty {
                Text(description)
                    .dsSecondaryText(font: .body)
            }
        } actions: {
            Button(actionTitle, action: onAction)
                .dsIconLabelButton()
        }
    }
}
