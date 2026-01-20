import SwiftUI
import UniformTypeIdentifiers

/// Provider Settings View - displays all configured providers
public struct ProviderSettingsView: View {
    @ObservedObject var settings: ProviderSettings

    public init(settings: ProviderSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section(
                NSLocalizedString("settings.providers_config", comment: "Providers Configuration")
            ) {
                ForEach(settings.providers) { provider in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: provider.iconName)
                                .foregroundStyle(.secondary)
                            Text(provider.name)
                                .font(.headline)
                            Spacer()
                        }

                        Divider()

                        // Path Display
                        VStack(alignment: .leading) {
                            Text(NSLocalizedString("settings.skills_path", comment: "Skills Path"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(provider.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(provider.path)
                        }

                        // Installation Method Display
                        VStack(alignment: .leading) {
                            Text(
                                NSLocalizedString(
                                    "settings.install_method", comment: "Installation Method")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(provider.installMethod.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                Text(
                    NSLocalizedString("settings.note", comment: "Note")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(NSLocalizedString("settings.title", comment: "Settings"))
    }
}
