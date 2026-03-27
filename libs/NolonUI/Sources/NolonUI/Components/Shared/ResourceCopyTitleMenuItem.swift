import SwiftUI

public struct ResourceCopyTitleMenuItem: View {
    private static let defaultTitle = NSLocalizedString(
        "resource.card.copy_title",
        value: "Copy Title",
        comment: "Copy resource title"
    )
    private static let defaultSystemImage = "doc.on.doc"

    private let titleToCopy: String
    private let onCopy: (String) -> Void

    public init(titleToCopy: String, onCopy: @escaping (String) -> Void) {
        self.titleToCopy = titleToCopy
        self.onCopy = onCopy
    }

    public var body: some View {
        Button {
            onCopy(titleToCopy)
        } label: {
            Label(Self.defaultTitle, systemImage: Self.defaultSystemImage)
        }
    }
}
