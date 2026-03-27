import SwiftUI
import NolonUIFoundation

public struct ProviderSkillsTopControlsView: View {
    let providerPickerTitle: String
    let providers: [ProviderSkillsOption]
    @Binding var selectedProviderIndex: Int
    let migrationBannerTitle: String
    let migrationBannerDescription: String
    let migrationBannerActionTitle: String
    let showsMigrationBanner: Bool
    let onMigrateAll: () -> Void

    public init(
        providerPickerTitle: String = NSLocalizedString("provider_picker.label", value: "Provider", comment: "Provider picker label"),
        providers: [ProviderSkillsOption],
        selectedProviderIndex: Binding<Int>,
        migrationBannerTitle: String = NSLocalizedString("banner.orphaned_title", value: "Orphaned Skills Detected", comment: "Orphaned skills banner title"),
        migrationBannerDescription: String = NSLocalizedString("banner.orphaned_desc", value: "Some skills are not managed by this provider yet.", comment: "Orphaned skills banner description"),
        migrationBannerActionTitle: String = NSLocalizedString("action.import_all", value: "Import All", comment: "Import all action"),
        showsMigrationBanner: Bool,
        onMigrateAll: @escaping () -> Void
    ) {
        self.providerPickerTitle = providerPickerTitle
        self.providers = providers
        self._selectedProviderIndex = selectedProviderIndex
        self.migrationBannerTitle = migrationBannerTitle
        self.migrationBannerDescription = migrationBannerDescription
        self.migrationBannerActionTitle = migrationBannerActionTitle
        self.showsMigrationBanner = showsMigrationBanner
        self.onMigrateAll = onMigrateAll
    }

    public var body: some View {
        if !providers.isEmpty {
            Picker(providerPickerTitle, selection: $selectedProviderIndex) {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    Text(provider.title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding()
        }

        if showsMigrationBanner {
            OrphanedSkillsMigrationBannerView(
                title: migrationBannerTitle,
                description: migrationBannerDescription,
                actionTitle: migrationBannerActionTitle,
                onAction: onMigrateAll
            )
            .padding(.horizontal)
        }
    }
}
