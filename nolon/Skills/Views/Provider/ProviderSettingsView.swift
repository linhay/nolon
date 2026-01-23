import SwiftUI
import UniformTypeIdentifiers

/// Provider Settings View - displays all configured providers with editing support
public struct ProviderSettingsView: View {
    @ObservedObject var settings: ProviderSettings
    @State private var editingProvider: Provider?

    public init(settings: ProviderSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section(
                NSLocalizedString("settings.providers_config", comment: "Providers Configuration")
            ) {
                ForEach(settings.providers) { provider in
                    ProviderSettingsRowView(provider: provider)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingProvider = provider
                        }
                        .contextMenu {
                            Button {
                                editingProvider = provider
                            } label: {
                                Label(
                                    NSLocalizedString("action.edit", comment: "Edit"),
                                    systemImage: "pencil")
                            }

                            Button {
                                let url = URL(fileURLWithPath: provider.skillsPath)
                                NSWorkspace.shared.selectFile(
                                    nil, inFileViewerRootedAtPath: url.path)
                            } label: {
                                Label(
                                    NSLocalizedString(
                                        "action.show_in_finder", comment: "Show in Finder"),
                                    systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                settings.removeProvider(provider)
                            } label: {
                                Label(
                                    NSLocalizedString("action.delete", comment: "Delete"),
                                    systemImage: "trash")
                            }
                        }
                }
                .onDelete { offsets in
                    settings.removeProvider(at: offsets)
                }
                .onMove { source, destination in
                    settings.moveProvider(from: source, to: destination)
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
        .sheet(item: $editingProvider) { provider in
            EditProviderSheet(settings: settings, provider: provider)
        }
    }
}

/// Row view for a provider in settings
struct ProviderSettingsRowView: View {
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: provider.iconName)
                    .foregroundStyle(.secondary)
                Text(provider.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Path Display
            VStack(alignment: .leading) {
                Text(NSLocalizedString("settings.skills_path", comment: "Skills Path"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(provider.skillsPath)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(provider.skillsPath)
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
