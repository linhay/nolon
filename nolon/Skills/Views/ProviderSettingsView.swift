import SwiftUI
import UniformTypeIdentifiers

public struct ProviderSettingsView: View {
    @ObservedObject var settings: ProviderSettings
    @State private var showingFileImporter = false
    @State private var selectedProviderForImport: SkillProvider?

    public init(settings: ProviderSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section(
                NSLocalizedString("settings.providers_config", comment: "Providers Configuration")
            ) {
                ForEach(SkillProvider.allCases, id: \.self) { provider in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(provider.displayName)
                                .font(.headline)
                            Spacer()
                            if let icon = providerIcon(for: provider) {
                                Image(systemName: icon)
                            }
                        }

                        Divider()

                        // Path Configuration
                        VStack(alignment: .leading) {
                            Text(NSLocalizedString("settings.skills_path", comment: "Skills Path"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text(settings.path(for: provider).path)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(settings.path(for: provider).path)

                                Spacer()

                                Button(
                                    NSLocalizedString("settings.change_btn", comment: "Change...")
                                ) {
                                    selectedProviderForImport = provider
                                    showingFileImporter = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        // Installation Method
                        VStack(alignment: .leading) {
                            Text(
                                NSLocalizedString(
                                    "settings.install_method", comment: "Installation Method")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Picker(
                                "",
                                selection: Binding(
                                    get: { settings.method(for: provider) },
                                    set: { settings.updateMethod($0, for: provider) }
                                )
                            ) {
                                ForEach(SkillInstallationMethod.allCases) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
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
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .navigationTitle(NSLocalizedString("settings.title", comment: "Settings"))
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, let provider = selectedProviderForImport else { return }
            settings.updatePath(url, for: provider)
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
        selectedProviderForImport = nil
    }

    private func providerIcon(for provider: SkillProvider) -> String? {
        switch provider {
        case .codex: return "terminal"
        case .claude: return "bubble.left.and.bubble.right"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .copilot: return "airplane"
        case .gemini: return "sparkles"
        case .antigravity: return "arrow.up.circle"
        }
    }
}
