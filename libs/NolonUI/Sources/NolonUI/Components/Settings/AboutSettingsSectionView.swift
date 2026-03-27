import SwiftUI
import NolonUIFoundation

public struct AboutSettingsSectionView: View {
    let data: AboutSettingsData
    let onCheckUpdates: () -> Void

    public init(data: AboutSettingsData, onCheckUpdates: @escaping () -> Void) {
        self.data = data
        self.onCheckUpdates = onCheckUpdates
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(data.appName)
                        .font(.system(size: 15, weight: .bold))

                    if let version = data.version, !version.isEmpty {
                        Text(version)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                    }
                }

                Text(data.description)
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()

            Button(action: onCheckUpdates) {
                HStack {
                    Text(data.checkUpdatesTitle)
                    Spacer()
                    Image(systemName: "arrow.up.circle")
                        .dsSecondaryText(font: .body)
                }
                .padding(16)
                .dsCard()
            }
            .dsLinkButton()
        }
    }
}
