import SwiftUI

public struct UnavailableStateView: View {
    let title: String
    let systemImage: String
    let description: String?

    public init(
        title: String,
        systemImage: String,
        description: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
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
        }
    }
}
