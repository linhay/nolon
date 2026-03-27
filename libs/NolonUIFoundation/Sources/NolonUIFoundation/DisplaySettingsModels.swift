import Foundation

public struct DisplaySettingsOptionRowData: Identifiable {
    public let id: String
    public let row: SelectableSettingsRowData

    public init(
        id: String,
        row: SelectableSettingsRowData
    ) {
        self.id = id
        self.row = row
    }
}

public struct DisplaySettingsContentData {
    public let appearanceTitle: String
    public let appearanceOptions: [DisplaySettingsOptionRowData]
    public let languageTitle: String
    public let languageOptions: [DisplaySettingsOptionRowData]

    public init(
        appearanceTitle: String,
        appearanceOptions: [DisplaySettingsOptionRowData],
        languageTitle: String,
        languageOptions: [DisplaySettingsOptionRowData]
    ) {
        self.appearanceTitle = appearanceTitle
        self.appearanceOptions = appearanceOptions
        self.languageTitle = languageTitle
        self.languageOptions = languageOptions
    }
}
