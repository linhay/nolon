import SwiftUI
import NolonUIFoundation

public struct SettingsWorkspaceCardView: View {
    let data: SettingsWorkspaceCardData

    public init(data: SettingsWorkspaceCardData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.label)
                .font(.caption)
                .dsSecondaryText(font: .caption)

            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .dsSecondaryText(font: .body)
                Text(data.path)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
        }
    }
}
