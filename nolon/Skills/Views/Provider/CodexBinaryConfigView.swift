import Observation
import ProviderCatalog
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import STFilePath

@MainActor
@Observable
final class CodexBinaryConfigViewModel {
    var manifest: CodexBinaryManifest = .default
    var isLoading = false
    var isCheckingUpdates = false
    var errorMessage: String?
    var preferredModelDraft: String = ""
    var currentCLIVersion: String = ""
    var isDownloadingRemoteVersion = false
    var remoteDownloadProgress: CodexDownloadProgress?
    var remoteReleases: [CodexRemoteRelease] = []
    var activeRemoteDownloadTag: String?
    var pathStatus: CodexBinaryManager.CodexPathStatus?
    var isConfiguringPath = false
    var isCheckingPath = false

    private let manager: CodexBinaryManager
    private let provider: Provider

    init(provider: Provider, manager: CodexBinaryManager = .shared) {
        self.provider = provider
        self.manager = manager
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await manager.discoverXcodeAgentVersions()
            manifest = await manager.checkForRustReleaseUpdateIfNeeded(force: false)
            preferredModelDraft = loadModelFromConfig() ?? manifest.preferredModel ?? ""
            await refreshRemoteReleases()
            await refreshCurrentCLIVersion()
            if !isCodexXcodeProvider {
                await refreshPathStatus()
            } else {
                pathStatus = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkUpdates(force: Bool = true) async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        manifest = await manager.checkForRustReleaseUpdateIfNeeded(force: force)
        await refreshRemoteReleases()
    }

    func importLocalBinary(from url: URL) async {
        do {
            _ = try await manager.importBinary(from: url)
            manifest = try await manager.loadManifest()
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadLatest() async {
        guard let raw = manifest.lastSeenRemoteAssetURL, let url = URL(string: raw) else {
            return
        }

        do {
            isDownloadingRemoteVersion = true
            remoteDownloadProgress = CodexDownloadProgress(fractionCompleted: nil, completedBytes: nil, totalBytes: nil)
            activeRemoteDownloadTag = manifest.lastSeenRemoteTag
            _ = try await manager.downloadAndImport(from: url, progress: { [weak self] progress in
                self?.remoteDownloadProgress = progress
            })
            manifest = try await manager.loadManifest()
            await refreshRemoteReleases()
            await refreshCurrentCLIVersion()
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        } catch {
            errorMessage = error.localizedDescription
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        }
    }

    func downloadRemoteRelease(_ release: CodexRemoteRelease) async {
        do {
            isDownloadingRemoteVersion = true
            remoteDownloadProgress = CodexDownloadProgress(fractionCompleted: nil, completedBytes: nil, totalBytes: nil)
            activeRemoteDownloadTag = release.tag
            _ = try await manager.downloadAndImport(from: release.assetURL, progress: { [weak self] progress in
                self?.remoteDownloadProgress = progress
            })
            manifest = try await manager.loadManifest()
            await refreshRemoteReleases()
            await refreshCurrentCLIVersion()
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        } catch {
            errorMessage = error.localizedDescription
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        }
    }

    func activate(versionId: String) async {
        do {
            try await manager.activate(versionId: versionId)
            manifest = try await manager.loadManifest()
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(versionId: String) async {
        do {
            try await manager.remove(versionId: versionId)
            manifest = try await manager.loadManifest()
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applySelectedModel(_ model: String) async {
        do {
            let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            try await manager.applyModelToConfig(trimmed, configFile: resolvedConfigFile())
            manifest = try await manager.loadManifest()
            preferredModelDraft = trimmed
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPathStatus() async {
        guard !isCodexXcodeProvider else {
            pathStatus = nil
            return
        }
        isCheckingPath = true
        defer { isCheckingPath = false }
        pathStatus = await manager.codexPathStatus()
    }

    func installPath() async {
        guard !isCodexXcodeProvider else { return }
        isConfiguringPath = true
        defer { isConfiguringPath = false }
        do {
            try await manager.installCodexPathToShellProfile()
            pathStatus = await manager.codexPathStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPreferredModel() async {
        do {
            try await manager.clearPreferredModel(configFile: resolvedConfigFile())
            manifest = try await manager.loadManifest()
            preferredModelDraft = ""
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openModelConfig() async {
        let configFile = resolvedConfigFile()
        let configURL = configFile?.url
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/config.toml")
        do {
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: configURL.path) {
                let initialModel = preferredModelDraft.nonEmpty ?? "gpt-5.3-codex"
                try "model = \"\(initialModel)\"\n".write(to: configURL, atomically: true, encoding: .utf8)
            }
            NSWorkspace.shared.open(configURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openGitHubReleases() {
        guard let url = URL(string: "https://github.com/openai/codex/releases") else { return }
        NSWorkspace.shared.open(url)
    }

    func isCodexProvider() -> Bool {
        provider.templateId == "codex" || provider.templateId == "codexXcode"
    }

    var isCodexXcodeProvider: Bool {
        provider.templateId == "codexXcode"
    }

    func statusText() -> String {
        switch manifest.updateState {
        case .idle:
            return NSLocalizedString("codex.binary.update.idle", value: "Not checked yet", comment: "Update status")
        case .checking:
            return NSLocalizedString("codex.binary.update.checking", value: "Checking updates...", comment: "Update status")
        case .upToDate:
            return NSLocalizedString("codex.binary.update.up_to_date", value: "Up to date", comment: "Update status")
        case .updateAvailable:
            if let version = manifest.lastSeenRemoteVersion {
                return String(
                    format: NSLocalizedString("codex.binary.update.available", value: "Update available: %@", comment: "Update status"),
                    version
                )
            }
            return NSLocalizedString("codex.binary.update.available_generic", value: "Update available", comment: "Update status")
        case .checkFailed:
            return NSLocalizedString("codex.binary.update.failed", value: "Update check failed", comment: "Update status")
        }
    }

    var localVersionsSorted: [ManagedCodexVersion] {
        manifest.versions.sorted { lhs, rhs in
            let compared = CodexBinaryManager.compareVersion(lhs.detectedVersion, rhs.detectedVersion)
            if compared == 0 {
                return lhs.importedAt > rhs.importedAt
            }
            return compared > 0
        }
    }

    var showBetaVersions: Bool {
        manifest.includeBetaVersions
    }

    var hasUpdateAvailable: Bool {
        manifest.updateState == .updateAvailable && manifest.lastSeenRemoteAssetURL != nil
    }

    var remoteVersion: (version: String, assetURL: URL)? {
        guard hasUpdateAvailable,
              let version = manifest.lastSeenRemoteVersion,
              let raw = manifest.lastSeenRemoteAssetURL,
              let url = URL(string: raw) else {
            return nil
        }
        let alreadyInstalled = manifest.versions.contains { $0.detectedVersion == version }
        return alreadyInstalled ? nil : (version, url)
    }

    var remoteReleaseRows: [CodexRemoteRelease] {
        let installed = Set(manifest.versions.map(\.detectedVersion))
        let installedURLs = Set(manifest.versions.compactMap(\.sourceURL))
        let candidates = showBetaVersions
            ? remoteReleases
            : remoteReleases.filter { !$0.isPrerelease }
        let filtered = candidates.filter { candidate in
            if installed.contains(candidate.version) { return false }
            if installedURLs.contains(candidate.assetURL.absoluteString) { return false }
            return true
        }
        return filtered.sorted { lhs, rhs in
            let compared = CodexBinaryManager.compareVersion(lhs.version, rhs.version)
            if compared == 0 {
                return lhs.tag > rhs.tag
            }
            return compared > 0
        }
    }

    var combinedVersionRows: [VersionRow] {
        let local = localVersionsSorted.map { VersionRow.local($0) }
        let remote = remoteReleaseRows.map { VersionRow.remote($0) }
        return (local + remote).sorted { lhs, rhs in
            let compared = CodexBinaryManager.compareVersion(lhs.versionString, rhs.versionString)
            if compared == 0 {
                return lhs.secondarySortKey > rhs.secondarySortKey
            }
            return compared > 0
        }
    }

    var primaryActionTitle: String {
        if hasUpdateAvailable, let version = manifest.lastSeenRemoteVersion, !version.isEmpty {
            return String(
                format: NSLocalizedString(
                    "codex.binary.download_specific",
                    value: "Download %@",
                    comment: "Download specific version"
                ),
                version
            )
        }
        return NSLocalizedString("codex.binary.check_updates", value: "Check Updates", comment: "Check updates")
    }

    func runPrimaryAction() async {
        if hasUpdateAvailable {
            await downloadLatest()
        } else {
            await checkUpdates(force: true)
        }
    }

    func setShowBetaVersions(_ enabled: Bool) async {
        do {
            try await manager.setIncludeBetaVersions(enabled)
            manifest = try await manager.loadManifest()
            await checkUpdates(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRemoteReleases() async {
        do {
            remoteReleases = try await manager.fetchRemoteReleases(includePrerelease: showBetaVersions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolvedConfigFile() -> STFile? {
        let rawSkillsPath = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        if !rawSkillsPath.isEmpty {
            let skillsURL = URL(fileURLWithPath: rawSkillsPath, isDirectory: true)
            let codexHome = skillsURL.deletingLastPathComponent()
            return STFile(codexHome.appendingPathComponent("config.toml").path)
        }

        let fallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/config.toml")
        return STFile(fallback.path)
    }

    private func loadModelFromConfig() -> String? {
        guard let configFile = resolvedConfigFile(),
              FileManager.default.fileExists(atPath: configFile.url.path),
              let content = try? String(contentsOf: configFile.url, encoding: .utf8) else {
            return nil
        }
        return Self.parsePreferredModel(from: content)
    }

    static func parsePreferredModel(from content: String) -> String? {
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equalIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard key == "model" else { continue }
            let rhs = trimmed[trimmed.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if rhs.hasPrefix("\""), rhs.hasSuffix("\""), rhs.count >= 2 {
                return String(rhs.dropFirst().dropLast())
            }
            return rhs.nonEmpty
        }
        return nil
    }

    private func refreshCurrentCLIVersion() async {
        do {
            if isCodexXcodeProvider {
                if let xcodeURL = await manager.xcodeAgentCodexBinaryURL(),
                   let version = await manager.detectCodexVersion(at: xcodeURL),
                   !version.isEmpty
                {
                    currentCLIVersion = version
                    return
                }
            } else if let version = try await manager.currentCLIVersion(), !version.isEmpty {
                currentCLIVersion = version
                return
            }
        } catch {
            // Keep UI resilient; fallback to unknown.
        }
        currentCLIVersion = NSLocalizedString("codex.binary.cli_version.unknown", value: "Unknown", comment: "Unknown CLI version")
    }
}

enum VersionRow: Identifiable, Hashable {
    case remote(CodexRemoteRelease)
    case local(ManagedCodexVersion)

    var id: String {
        switch self {
        case .remote(let release):
            return "remote-\(release.tag)"
        case .local(let version):
            return "local-\(version.id)"
        }
    }

    var versionString: String {
        switch self {
        case .remote(let release):
            return release.version
        case .local(let version):
            return version.detectedVersion
        }
    }

    var secondarySortKey: String {
        switch self {
        case .remote(let release):
            return release.tag
        case .local(let version):
            return version.id
        }
    }
}

struct CodexBinaryConfigView: View {
    let provider: Provider
    @State private var viewModel: CodexBinaryConfigViewModel
    @State private var showingImporter = false

    init(provider: Provider) {
        self.provider = provider
        self._viewModel = State(initialValue: CodexBinaryConfigViewModel(provider: provider))
    }

    var body: some View {
        Group {
            if !viewModel.isCodexProvider() {
                ContentUnavailableView(
                    NSLocalizedString("codex.binary.not_supported.title", value: "Not Supported", comment: "Not supported"),
                    systemImage: "shippingbox",
                    description: Text(NSLocalizedString("codex.binary.not_supported.desc", value: "Binary management is only available for Codex providers.", comment: "Not supported"))
                )
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .task {
            await viewModel.load()
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await viewModel.importLocalBinary(from: url) }
        }
        .alert(
            NSLocalizedString("codex.binary.error.title", value: "Binary Error", comment: "Binary error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK")) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if viewModel.isCheckingUpdates {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(NSLocalizedString("codex.binary.update.checking", value: "Checking updates...", comment: "Update status"))
                        .font(.callout)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .dsCard(
                    background: DesignSystem.Colors.Background.elevated.opacity(0.94),
                    cornerRadius: DesignSystem.Metrics.cornerRadiusM,
                    borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
                )
                .padding(.top, 12)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    NSLocalizedString("codex.binary.section.update_versions", value: "Versions", comment: "Merged versions section")
                )
                mergedVersionSection

                sectionHeader(
                    NSLocalizedString("codex.binary.section.preferences", value: "Run Preferences", comment: "Preferences section")
                )
                preferencesSection
            }
            .padding()
        }
    }

    private var mergedVersionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.hasUpdateAvailable ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success)
                    .frame(width: 8, height: 8)
                Text(viewModel.statusText())
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Text(NSLocalizedString("codex.binary.cli_version", value: "Current CLI", comment: "Current CLI version"))
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Text(viewModel.currentCLIVersion)
                    .font(.callout.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
            }

            ViewThatFits(in: .horizontal) {
                expandedActionRow
                compactActionRow
            }

            versionTable
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("codex.binary.model_placeholder", value: "preferred model (e.g. gpt-5.3-codex)", comment: "Model placeholder"))
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Button(NSLocalizedString("generic.save", value: "Save", comment: "Save")) {
                    Task { await viewModel.applySelectedModel(viewModel.preferredModelDraft) }
                }
                .dsPrimaryButton()
                .disabled(viewModel.preferredModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(NSLocalizedString("generic.clear", value: "Clear", comment: "Clear")) {
                    Task { await viewModel.clearPreferredModel() }
                }
                .dsSecondaryButton()
                .disabled(viewModel.preferredModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(NSLocalizedString("codex.binary.open_config", value: "Open Config", comment: "Open config file")) {
                    Task { await viewModel.openModelConfig() }
                }
                .dsSecondaryButton()
            }
            textInputField(
                placeholder: NSLocalizedString("codex.binary.model_placeholder", value: "preferred model (e.g. gpt-5.3-codex)", comment: "Model placeholder"),
                text: $viewModel.preferredModelDraft
            )

            if !viewModel.isCodexXcodeProvider, viewModel.pathStatus?.configured != true {
                Divider()
                    .padding(.vertical, 6)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("codex.binary.path.section", value: "Terminal PATH", comment: "PATH section title"))
                            .font(.callout)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        HStack(spacing: 8) {
                            if viewModel.isCheckingPath {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            if let status = viewModel.pathStatus {
                                Text(pathStatusText(status))
                                    .font(.footnote)
                                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Button(NSLocalizedString("codex.binary.path.configure", value: "Add to PATH", comment: "Add codex path to shell profile")) {
                        Task { await viewModel.installPath() }
                    }
                    .dsPrimaryButton()
                    .disabled(viewModel.isConfiguringPath || viewModel.isCheckingPath)
                    Button(NSLocalizedString("codex.binary.path.check", value: "Check", comment: "Check PATH status")) {
                        Task { await viewModel.refreshPathStatus() }
                    }
                    .dsSecondaryButton()
                    .disabled(viewModel.isConfiguringPath || viewModel.isCheckingPath)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }

    private var expandedActionRow: some View {
        HStack(spacing: 10) {
            Button(viewModel.primaryActionTitle) {
                Task { await viewModel.runPrimaryAction() }
            }
            .dsPrimaryButton()
            .disabled(viewModel.isCheckingUpdates || viewModel.isDownloadingRemoteVersion)

            Button(NSLocalizedString("codex.binary.import_local", value: "Import Local Binary", comment: "Import local")) {
                showingImporter = true
            }
            .dsSecondaryButton()
            .disabled(viewModel.isCheckingUpdates || viewModel.isDownloadingRemoteVersion)

            Button(NSLocalizedString("codex.binary.github", value: "Open GitHub Releases", comment: "Open GitHub releases")) {
                viewModel.openGitHubReleases()
            }
            .dsSecondaryButton()
            .disabled(viewModel.isCheckingUpdates || viewModel.isDownloadingRemoteVersion)

            Spacer(minLength: 0)
            Toggle(
                NSLocalizedString("codex.binary.beta.toggle", value: "Show beta versions", comment: "Show beta versions toggle"),
                isOn: Binding(
                    get: { viewModel.showBetaVersions },
                    set: { enabled in
                        Task { await viewModel.setShowBetaVersions(enabled) }
                    }
                )
            )
            .toggleStyle(.switch)
        }
    }

    private var compactActionRow: some View {
        HStack(spacing: 10) {
            Button(viewModel.primaryActionTitle) {
                Task { await viewModel.runPrimaryAction() }
            }
            .dsPrimaryButton()
            .disabled(viewModel.isCheckingUpdates || viewModel.isDownloadingRemoteVersion)

            Menu {
                Button(NSLocalizedString("codex.binary.check_updates", value: "Check Updates", comment: "Check updates")) {
                    Task { await viewModel.checkUpdates(force: true) }
                }
                Button(NSLocalizedString("codex.binary.import_local", value: "Import Local Binary", comment: "Import local")) {
                    showingImporter = true
                }
                Button(NSLocalizedString("codex.binary.github", value: "Open GitHub Releases", comment: "Open GitHub releases")) {
                    viewModel.openGitHubReleases()
                }
            } label: {
                Label(
                    NSLocalizedString("codex.binary.more_actions", value: "More", comment: "More actions"),
                    systemImage: "ellipsis.circle"
                )
            }
            .dsSecondaryButton()
            .disabled(viewModel.isCheckingUpdates || viewModel.isDownloadingRemoteVersion)
            Spacer(minLength: 0)
            Toggle(
                NSLocalizedString("codex.binary.beta.toggle", value: "Show beta versions", comment: "Show beta versions toggle"),
                isOn: Binding(
                    get: { viewModel.showBetaVersions },
                    set: { enabled in
                        Task { await viewModel.setShowBetaVersions(enabled) }
                    }
                )
            )
            .toggleStyle(.switch)
        }
    }

    private func textInputField(placeholder: String, text: Binding<String>) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsField(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
    }

    private func formatByteProgress(completed: Int64, total: Int64) -> String {
        func formatBytes(_ value: Int64) -> String {
            let kb: Double = 1024
            let mb = kb * 1024
            let gb = mb * 1024
            let bytes = Double(value)
            if bytes >= gb { return String(format: "%.1f GB", bytes / gb) }
            if bytes >= mb { return String(format: "%.1f MB", bytes / mb) }
            if bytes >= kb { return String(format: "%.1f KB", bytes / kb) }
            return String(format: "%.0f B", bytes)
        }
        if total <= 0 {
            return String(
                format: NSLocalizedString("codex.binary.download.progress.single", value: "Downloaded %@", comment: "Download progress bytes without total"),
                formatBytes(completed)
            )
        }
        return String(
            format: NSLocalizedString("codex.binary.download.progress", value: "%@ / %@", comment: "Download progress bytes"),
            formatBytes(completed),
            formatBytes(total)
        )
    }

    private func pathStatusText(_ status: CodexBinaryManager.CodexPathStatus) -> String {
        let configured = status.configured
            ? NSLocalizedString("codex.binary.path.configured", value: "Yes", comment: "Configured label")
            : NSLocalizedString("codex.binary.path.not_configured", value: "No", comment: "Not configured label")
        let active = status.active
            ? NSLocalizedString("codex.binary.path.active", value: "Yes", comment: "Active label")
            : NSLocalizedString("codex.binary.path.inactive", value: "No", comment: "Inactive label")
        return String(
            format: NSLocalizedString(
                "codex.binary.path.status",
                value: "Shell: %@ (%@) • Configured: %@ • Active: %@",
                comment: "PATH status line"
            ),
            status.shellName,
            status.profilePath,
            configured,
            active
        )
    }

    private var versionTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(NSLocalizedString("codex.binary.table.name", value: "Name", comment: "Version table name"))
                    .frame(width: 200, alignment: .leading)
                Text(NSLocalizedString("codex.binary.table.version", value: "Version", comment: "Version table version"))
                    .frame(width: 110, alignment: .leading)
                Text(NSLocalizedString("codex.binary.table.source", value: "Source", comment: "Version table source"))
                    .frame(width: 110, alignment: .leading)
                Text(NSLocalizedString("codex.binary.table.state", value: "State", comment: "Version table state"))
                    .frame(width: 80, alignment: .leading)
                Text(NSLocalizedString("codex.binary.table.actions", value: "Actions", comment: "Version table actions"))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()
                .overlay(DesignSystem.Colors.Component.border.opacity(0.35))

            ForEach(Array(viewModel.combinedVersionRows.enumerated()), id: \.element.id) { index, row in
                let isLast = index == viewModel.combinedVersionRows.count - 1
                switch row {
                case .remote(let release):
                    let isActiveDownload = viewModel.isDownloadingRemoteVersion && viewModel.activeRemoteDownloadTag == release.tag
                    HStack(spacing: 10) {
                        Text(String(
                            format: NSLocalizedString("codex.binary.version.github", value: "Codex %@", comment: "GitHub version name"),
                            release.version
                        ))
                        .frame(width: 200, alignment: .leading)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        Text("v\(release.version)")
                            .font(.callout.monospaced())
                            .frame(width: 110, alignment: .leading)
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        Text(NSLocalizedString("codex.binary.source.github", value: "GitHub", comment: "GitHub source"))
                            .font(.callout)
                            .frame(width: 110, alignment: .leading)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        Text(
                            isActiveDownload
                            ? NSLocalizedString("codex.binary.state.downloading", value: "Downloading", comment: "Downloading state")
                            : NSLocalizedString("codex.binary.state.available", value: "Available", comment: "Available state")
                        )
                        .frame(width: 80, alignment: .leading)
                        .foregroundStyle(DesignSystem.Colors.Status.warning)
                        if isActiveDownload {
                            VStack(alignment: .trailing, spacing: 4) {
                                if let progress = viewModel.remoteDownloadProgress,
                                   let completed = progress.completedBytes,
                                   let total = progress.totalBytes {
                                    ProgressView(value: progress.fractionCompleted ?? 0)
                                        .frame(width: 70, alignment: .trailing)
                                    Text(formatByteProgress(completed: completed, total: total))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                } else {
                                    ProgressView()
                                        .frame(width: 70, alignment: .trailing)
                                    Text(NSLocalizedString("codex.binary.downloading", value: "Downloading…", comment: "Downloading label"))
                                        .font(.caption2)
                                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                }
                            }
                        } else {
                            Button(NSLocalizedString("codex.binary.download", value: "Download", comment: "Download")) {
                                Task { await viewModel.downloadRemoteRelease(release) }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DesignSystem.Colors.primary)
                            .disabled(viewModel.isDownloadingRemoteVersion)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                case .local(let version):
                    HStack(spacing: 10) {
                        Text(version.displayName)
                            .frame(width: 200, alignment: .leading)
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        Text("v\(version.detectedVersion)")
                            .font(.callout.monospaced())
                            .frame(width: 110, alignment: .leading)
                            .foregroundStyle(DesignSystem.Colors.Text.primary)
                        Text(version.source)
                            .font(.callout)
                            .frame(width: 110, alignment: .leading)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        Text(
                            viewModel.manifest.selectedVersionId == version.id
                            ? NSLocalizedString("codex.binary.active", value: "Active", comment: "Active")
                            : NSLocalizedString("codex.binary.inactive", value: "Inactive", comment: "Inactive")
                        )
                        .frame(width: 80, alignment: .leading)
                        .foregroundStyle(
                            viewModel.manifest.selectedVersionId == version.id
                            ? DesignSystem.Colors.Status.success
                            : DesignSystem.Colors.Text.secondary
                        )
                        Button(NSLocalizedString("generic.delete", value: "Delete", comment: "Delete")) {
                            Task { await viewModel.remove(versionId: version.id) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DesignSystem.Colors.Status.error)
                        .disabled(viewModel.manifest.selectedVersionId == version.id)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard viewModel.manifest.selectedVersionId != version.id else { return }
                        Task { await viewModel.activate(versionId: version.id) }
                    }
                }

                if !isLast {
                    Divider()
                        .overlay(DesignSystem.Colors.Component.border.opacity(0.28))
                }
            }
        }
        .dsCard(
            background: DesignSystem.Colors.Background.surface.opacity(0.38),
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.22)
        )
    }
}
