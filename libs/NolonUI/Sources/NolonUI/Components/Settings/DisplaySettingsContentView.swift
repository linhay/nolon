import SwiftUI
import NolonUIFoundation

public struct DisplaySettingsContentView: View {
    let data: DisplaySettingsContentData
    let onSelectAppearance: (String) -> Void
    let onSelectLanguage: (String) -> Void

    public init(
        data: DisplaySettingsContentData,
        onSelectAppearance: @escaping (String) -> Void,
        onSelectLanguage: @escaping (String) -> Void
    ) {
        self.data = data
        self.onSelectAppearance = onSelectAppearance
        self.onSelectLanguage = onSelectLanguage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSectionView(title: data.appearanceTitle) {
                SettingsCardRows {
                    ForEach(data.appearanceOptions) { option in
                        SelectableSettingsRowView(data: option.row) {
                            onSelectAppearance(option.id)
                        }
                    }
                }
            }

            SettingsSectionView(title: data.languageTitle) {
                SettingsCardRows {
                    ForEach(data.languageOptions) { option in
                        SelectableSettingsRowView(data: option.row) {
                            onSelectLanguage(option.id)
                        }
                    }
                }
            }
        }
    }
}
