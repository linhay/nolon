import SwiftUI

public struct ProviderGridEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    public init(
        title: String,
        systemImage: String,
        description: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    public var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
                .dsSecondaryText(font: .body)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
