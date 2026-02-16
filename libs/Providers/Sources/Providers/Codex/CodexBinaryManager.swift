import CryptoKit
import Foundation
import OSLog
import SKProcessRunner
import STFilePath
import ProvidersShared

public actor CodexBinaryManager {
    public static let shared = CodexBinaryManager()

    private static let logger = Logger(subsystem: "com.nolon", category: "CodexBinaryManager")
    private static let pathMarkerStart = "# >>> Nolon Codex PATH >>>"
    private static let pathMarkerEnd = "# <<< Nolon Codex PATH <<<"

    private let fileManager: FileManager
    private let userHomeFolder: STFolder
    private let nolonHomeFolder: STFolder
    private let throttlingInterval: TimeInterval = 24 * 60 * 60

    public init(
        fileManager: FileManager = .default,
        homeURL: URL = STFolder(NSHomeDirectory()).url,
        nolonHomeURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.userHomeFolder = STFolder(homeURL)
        if let nolonHomeURL {
            self.nolonHomeFolder = STFolder(nolonHomeURL)
        } else {
            self.nolonHomeFolder = NolonHomeEnvironment.resolveNolonHomeFolder(
                environment: environment,
                userHomeURL: homeURL
            )
        }
    }

    public var rootFolder: STFolder {
        STFolder(nolonHomeFolder.url.appendingPathComponent("codex", isDirectory: true))
    }

    public var versionsFolder: STFolder {
        STFolder(rootFolder.url.appendingPathComponent("versions", isDirectory: true))
    }

    public var currentLinkFolder: STFolder {
        STFolder(rootFolder.url.appendingPathComponent("current", isDirectory: true))
    }

    public var binaryShimFile: STFile {
        STFile(rootFolder.url.appendingPathComponent("bin/codex"))
    }

    private var manifestFile: STFile {
        STFile(rootFolder.url.appendingPathComponent("manifest.json"))
    }

    private var xcodeAgentsVersionsFolder: STFolder {
        STFolder(userHomeFolder.url.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/Agents/Versions", isDirectory: true))
    }

    public func xcodeAgentCodexBinaryURL() -> URL? {
        guard fileManager.fileExists(atPath: xcodeAgentsVersionsFolder.url.path) else { return nil }
        let entries = (try? fileManager.contentsOfDirectory(
            at: xcodeAgentsVersionsFolder.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var best: (version: String, url: URL)?
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let candidate = entry.appendingPathComponent("codex")
            guard fileManager.fileExists(atPath: candidate.path) else { continue }
            let version = entry.lastPathComponent
            if let currentBest = best {
                if compareXcodeVersion(version, currentBest.version) > 0 {
                    best = (version, candidate)
                }
            } else {
                best = (version, candidate)
            }
        }
        return best?.url
    }

    public var xcodeFixedCodexBinaryURL: URL {
        userHomeFolder.url.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/Agents/Versions/26.3/codex")
    }

    private var xcodeCodexConfigFile: STFile {
        STFile(userHomeFolder.url.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/codex/config.toml"))
    }

    private var pathExportLine: String {
        let codexBinPath = rootFolder.url.appendingPathComponent("bin", isDirectory: true).standardizedFileURL.path
        let homePath = userHomeFolder.url.standardizedFileURL.path
        if codexBinPath.hasPrefix(homePath + "/") {
            let suffix = String(codexBinPath.dropFirst(homePath.count))
            return "export PATH=\"$HOME\(suffix):$PATH\""
        }
        let escaped = codexBinPath.replacingOccurrences(of: "\"", with: "\\\"")
        return "export PATH=\"\(escaped):$PATH\""
    }

    public func listVersions() throws -> [ManagedCodexVersion] {
        let manifest = try loadManifest()
        return manifest.versions.sorted { $0.importedAt > $1.importedAt }
    }

    public struct CodexPathStatus: Sendable {
        public let shellName: String
        public let profilePath: String
        public let configured: Bool
        public let active: Bool
    }

    public func codexPathStatus() -> CodexPathStatus {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.nonEmpty ?? "shell"
        let profileRelative = resolveShellProfilePath(shellPath: shellPath)
        let profileURL = userHomeFolder.url.appendingPathComponent(profileRelative)
        let profileDisplay = displayPath(profileURL.path)
        let contents = (try? String(contentsOf: profileURL, encoding: .utf8)) ?? ""
        let codexBinPath = rootFolder.url.appendingPathComponent("bin", isDirectory: true).standardizedFileURL.path
        let configured = contents.contains(Self.pathMarkerStart)
            || contents.contains(pathExportLine)
            || contents.contains(codexBinPath)
        let active = isCodexBinInPATH()
        return CodexPathStatus(shellName: shellName, profilePath: profileDisplay, configured: configured, active: active)
    }

    public func installCodexPathToShellProfile() throws {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        let profileRelative = resolveShellProfilePath(shellPath: shellPath)
        let profileURL = userHomeFolder.url.appendingPathComponent(profileRelative)
        let existing = (try? String(contentsOf: profileURL, encoding: .utf8)) ?? ""

        let block = [
            Self.pathMarkerStart,
            pathExportLine,
            Self.pathMarkerEnd
        ].joined(separator: "\n")

        let updated = upsertPathBlock(existing, block: block)
        try updated.write(to: profileURL, atomically: true, encoding: .utf8)
    }

    public func loadManifest() throws -> CodexBinaryManifest {
        try ensureDirectories()
        guard fileManager.fileExists(atPath: manifestFile.url.path) else {
            return .default
        }

        let data = try Data(contentsOf: manifestFile.url)
        var manifest = try JSONDecoder().decode(CodexBinaryManifest.self, from: data)
        if manifest.schemaVersion <= 0 {
            manifest.schemaVersion = 1
        }
        return manifest
    }

    @discardableResult
    public func saveManifest(_ manifest: CodexBinaryManifest) throws -> CodexBinaryManifest {
        try ensureDirectories()
        let data = try JSONEncoder.pretty.encode(manifest)
        try data.write(to: manifestFile.url, options: .atomic)
        return manifest
    }

    @discardableResult
    public func importBinary(from sourceURL: URL, displayName: String? = nil, source: String = "manual", sourceURLString: String? = nil) throws -> ManagedCodexVersion {
        try ensureDirectories()
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "CodexBinaryManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Binary file does not exist."])
        }

        try ensureExecutable(at: sourceURL)
        let sha256 = try hashForFile(at: sourceURL)
        var manifest = try loadManifest()

        if let existing = manifest.versions.first(where: { $0.sha256 == sha256 }) {
            return existing
        }

        let detected = detectCodexVersion(at: sourceURL) ?? "unknown"
        let id = Self.makeVersionID(version: detected, hash: sha256)
        let versionFolder = versionsFolder.url.appendingPathComponent(id, isDirectory: true)
        let destination = versionFolder.appendingPathComponent("codex")
        try fileManager.createDirectory(at: versionFolder, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        try ensureExecutable(at: destination)

        let managed = ManagedCodexVersion(
            id: id,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Codex \(detected)",
            detectedVersion: detected,
            binaryRelativePath: "versions/\(id)/codex",
            sha256: sha256,
            source: source,
            sourceURL: sourceURLString,
            importedAt: Date(),
            notes: nil
        )

        manifest.versions.append(managed)
        manifest.versions.sort { $0.importedAt > $1.importedAt }
        try saveManifest(manifest)
        return managed
    }

    @discardableResult
    public func downloadAndImport(
        from downloadURL: URL,
        displayName: String? = nil,
        progress: ((CodexDownloadProgress) -> Void)? = nil
    ) async throws -> ManagedCodexVersion {
        let (tmpURL, response) = try await downloadFile(from: downloadURL, progress: progress)
        return try await importDownloadedFile(
            tmpURL: tmpURL,
            response: response,
            downloadURL: downloadURL,
            displayName: displayName
        )
    }

    private func downloadFile(from downloadURL: URL, progress: ((CodexDownloadProgress) -> Void)?) async throws -> (URL, URLResponse) {
        final class DownloadObservationBox: @unchecked Sendable {
            var observation: NSKeyValueObservation?
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
            let box = DownloadObservationBox()
            let task = URLSession.shared.downloadTask(with: downloadURL) { url, response, error in
                _ = box.observation
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url, let response else {
                    continuation.resume(throwing: NSError(domain: "CodexBinaryManager", code: 1010, userInfo: [NSLocalizedDescriptionKey: "Download failed."]))
                    return
                }
                Task { @MainActor in
                    progress?(CodexDownloadProgress(fractionCompleted: 1.0, completedBytes: nil, totalBytes: nil))
                }
                continuation.resume(returning: (url, response))
            }
            box.observation = task.progress.observe(\.fractionCompleted) { progressValue, _ in
                let total = progressValue.totalUnitCount
                let fraction = total > 0 ? progressValue.fractionCompleted : nil
                let totalBytes = total > 0 ? total : nil
                let completed = progressValue.completedUnitCount > 0 ? progressValue.completedUnitCount : nil
                Task { @MainActor in
                    progress?(CodexDownloadProgress(
                        fractionCompleted: fraction,
                        completedBytes: completed,
                        totalBytes: totalBytes
                    ))
                }
            }
            task.resume()
        }
    }

    private func importDownloadedFile(
        tmpURL: URL,
        response: URLResponse,
        downloadURL: URL,
        displayName: String?
    ) async throws -> ManagedCodexVersion {
        let tempFolder = rootFolder.url.appendingPathComponent("tmp", isDirectory: true)
        try fileManager.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        let responseName = response.suggestedFilename?.lowercased() ?? ""
        let archiveLikely = responseName.hasSuffix(".tar.gz")
            || responseName.hasSuffix(".tgz")
            || downloadURL.lastPathComponent.lowercased().hasSuffix(".tar.gz")
            || downloadURL.lastPathComponent.lowercased().hasSuffix(".tgz")
            || downloadURL.pathExtension.lowercased() == "gz"
            || downloadURL.pathExtension.lowercased() == "tgz"

        if archiveLikely {
            let archiveURL = tempFolder.appendingPathComponent("codex-download-\(UUID().uuidString).tar.gz")
            try? fileManager.removeItem(at: archiveURL)
            try fileManager.moveItem(at: tmpURL, to: archiveURL)
            defer { try? fileManager.removeItem(at: archiveURL) }

            let extractedBinary = try extractCodexBinary(fromArchive: archiveURL, tempFolder: tempFolder)
            defer { try? fileManager.removeItem(at: extractedBinary.deletingLastPathComponent()) }

            return try importBinary(
                from: extractedBinary,
                displayName: displayName,
                source: "download",
                sourceURLString: downloadURL.absoluteString
            )
        }

        let importedFile = tempFolder.appendingPathComponent("codex-\(UUID().uuidString)")
        try? fileManager.removeItem(at: importedFile)
        try fileManager.moveItem(at: tmpURL, to: importedFile)
        defer { try? fileManager.removeItem(at: importedFile) }

        return try importBinary(
            from: importedFile,
            displayName: displayName,
            source: "download",
            sourceURLString: downloadURL.absoluteString
        )
    }

    public func activate(versionId: String) throws {
        var manifest = try loadManifest()
        guard let selected = manifest.versions.first(where: { $0.id == versionId }) else {
            throw NSError(domain: "CodexBinaryManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Version not found."])
        }

        let versionBinary = rootFolder.url.appendingPathComponent(selected.binaryRelativePath)
        guard fileManager.fileExists(atPath: versionBinary.path) else {
            throw NSError(domain: "CodexBinaryManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Version binary missing on disk."])
        }

        try ensureDirectories()
        try replaceWithSymlink(at: currentLinkFolder.url, destination: versionBinary.deletingLastPathComponent().path)
        try replaceWithSymlink(at: binaryShimFile.url, destination: versionBinary.path)
        try applyXcodeAgentLinks(to: versionBinary)

        manifest.selectedVersionId = versionId
        try saveManifest(manifest)
        try syncPreferredModelIfNeeded(manifest: manifest)
    }

    public func remove(versionId: String) throws {
        var manifest = try loadManifest()
        guard manifest.selectedVersionId != versionId else {
            throw NSError(domain: "CodexBinaryManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Cannot remove active version."])
        }
        guard let version = manifest.versions.first(where: { $0.id == versionId }) else {
            return
        }

        let folder = rootFolder.url.appendingPathComponent(version.binaryRelativePath).deletingLastPathComponent()
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
        }
        manifest.versions.removeAll { $0.id == versionId }
        try saveManifest(manifest)
    }

    public func setSyncModelOnSwitch(_ enabled: Bool) throws {
        var manifest = try loadManifest()
        manifest.syncModelOnSwitch = enabled
        try saveManifest(manifest)
    }

    public func setPreferredModel(_ model: String?) throws {
        var manifest = try loadManifest()
        manifest.preferredModel = model?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        try saveManifest(manifest)
    }

    public func setIncludeBetaVersions(_ enabled: Bool) throws {
        var manifest = try loadManifest()
        manifest.includeBetaVersions = enabled
        try saveManifest(manifest)
    }

    public func applyModelToConfig(_ model: String?, configFile: STFile? = nil) throws {
        let trimmed = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return }
        var manifest = try loadManifest()
        manifest.preferredModel = trimmed
        try saveManifest(manifest)
        try writeModelToConfig(trimmed, file: configFile ?? xcodeCodexConfigFile)
    }

    public func clearPreferredModel(configFile: STFile? = nil) throws {
        var manifest = try loadManifest()
        manifest.preferredModel = nil
        try saveManifest(manifest)
        try removeModelFromConfig(file: configFile ?? xcodeCodexConfigFile)
    }

    public func setModelReasoningEffort(_ effort: String?, configFile: STFile? = nil) throws {
        let trimmed = effort?.trimmingCharacters(in: .whitespacesAndNewlines)
        let file = configFile ?? xcodeCodexConfigFile
        if let trimmed, !trimmed.isEmpty {
            try writeConfigValue(key: "model_reasoning_effort", value: trimmed, file: file)
        } else {
            try removeConfigValue(key: "model_reasoning_effort", file: file)
        }
    }

    public func setLaunchEnvironmentValue(_ value: String?, forKey rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        guard Self.isValidEnvironmentKey(key) else {
            throw NSError(
                domain: "CodexBinaryManager",
                code: 1008,
                userInfo: [NSLocalizedDescriptionKey: "Environment variable key is invalid."]
            )
        }
        guard !Self.isReservedEnvironmentKey(key) else {
            throw NSError(
                domain: "CodexBinaryManager",
                code: 1009,
                userInfo: [NSLocalizedDescriptionKey: "Environment variable key is reserved."]
            )
        }

        var manifest = try loadManifest()
        var env = manifest.launchEnvironment
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            env[key] = trimmed
        } else {
            env.removeValue(forKey: key)
        }
        manifest.launchEnvironment = Self.normalizedEnvironment(env)
        try saveManifest(manifest)
    }

    public func launchEnvironmentVariables() throws -> [String: String] {
        try loadManifest().launchEnvironment
    }

    public func cliLaunchCommand(codexHomePath: String, arguments: [String] = []) throws -> String {
        let escapedHome = Self.escapeShell(codexHomePath)
        var assignments: [String] = ["CODEX_HOME=\"\(escapedHome)\""]
        let env = try launchEnvironmentVariables()
        for key in env.keys.sorted() {
            guard let value = env[key], !value.isEmpty else { continue }
            assignments.append("\(key)=\"\(Self.escapeShell(value))\"")
        }
        let executable = executableForCLI()
        let args = arguments.map { "\"\(Self.escapeShell($0))\"" }.joined(separator: " ")
        if args.isEmpty {
            return assignments.joined(separator: " ") + " \(executable)"
        }
        return assignments.joined(separator: " ") + " \(executable) " + args
    }

    public func pathForVersion(_ version: ManagedCodexVersion) -> URL {
        rootFolder.url.appendingPathComponent(version.binaryRelativePath)
    }

    @discardableResult
    public func discoverXcodeAgentVersions() throws -> Int {
        guard fileManager.fileExists(atPath: xcodeAgentsVersionsFolder.url.path) else {
            return 0
        }

        let entries = try fileManager.contentsOfDirectory(
            at: xcodeAgentsVersionsFolder.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var importedCount = 0
        for entry in entries {
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let candidate = entry.appendingPathComponent("codex")
            guard fileManager.fileExists(atPath: candidate.path) else { continue }

            let previous = try loadManifest().versions.count
            _ = try importBinary(
                from: candidate,
                displayName: "Xcode \(entry.lastPathComponent)",
                source: "xcode-agent",
                sourceURLString: candidate.path
            )
            let latest = try loadManifest().versions.count
            if latest > previous {
                importedCount += 1
            }
        }

        return importedCount
    }

    public func activeCLIPath() -> String {
        binaryShimFile.url.path
    }

    public func activeCLIPathIfAvailable() -> String? {
        resolvedShimPathIfAvailable()
    }

    public func currentCLIVersion() throws -> String? {
        let manifest = try loadManifest()
        if let selectedID = manifest.selectedVersionId,
           let selected = manifest.versions.first(where: { $0.id == selectedID }),
           !selected.detectedVersion.isEmpty
        {
            return selected.detectedVersion
        }

        if let activePath = activeCLIPathIfAvailable(),
           let version = detectCodexVersion(at: URL(fileURLWithPath: activePath))
        {
            return version
        }

        return detectCodexVersionFromPATH()
    }

    public func detectCodexVersion(at url: URL) -> String? {
        detectCodexVersionInternal(at: url)
    }

    public func checkForRustReleaseUpdateIfNeeded(force: Bool = false) async -> CodexBinaryManifest {
        do {
            var manifest = try loadManifest()
            let now = Date()
            if !force,
               let last = manifest.lastUpdateCheckAt,
               now.timeIntervalSince(last) < throttlingInterval
            {
                return manifest
            }

            manifest.updateState = .checking
            try saveManifest(manifest)

            guard let release = try await fetchLatestRustRelease(includePrerelease: manifest.includeBetaVersions) else {
                manifest.updateState = .checkFailed
                manifest.lastUpdateCheckAt = now
                return try saveManifest(manifest)
            }

            manifest.lastSeenRemoteTag = release.tag
            manifest.lastSeenRemoteVersion = release.version
            manifest.lastSeenRemoteAssetURL = release.assetURL.absoluteString
            manifest.lastUpdateCheckAt = now

            let currentVersion = manifest.selectedVersionId
                .flatMap { id in manifest.versions.first { $0.id == id }?.detectedVersion }
                ?? highestInstalledVersion(in: manifest)
            if let currentVersion,
               Self.compareVersion(currentVersion, release.version) >= 0
            {
                manifest.updateState = .upToDate
            } else {
                manifest.updateState = .updateAvailable
            }

            return try saveManifest(manifest)
        } catch {
            Self.logger.error("Codex update check failed: \(String(describing: error), privacy: .public)")
            do {
                var manifest = try loadManifest()
                manifest.updateState = .checkFailed
                manifest.lastUpdateCheckAt = Date()
                return try saveManifest(manifest)
            } catch {
                return .default
            }
        }
    }

    // MARK: - Internal

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: rootFolder.url, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: versionsFolder.url, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: binaryShimFile.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: rootFolder.url.appendingPathComponent("backups/xcode", isDirectory: true), withIntermediateDirectories: true)
    }

    private func ensureExecutable(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        var attributes = try fileManager.attributesOfItem(atPath: url.path)
        let posix = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        if (posix & 0o111) == 0 {
            try fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: url.path)
            attributes = try fileManager.attributesOfItem(atPath: url.path)
            let updated = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
            if (updated & 0o111) == 0 {
                throw NSError(domain: "CodexBinaryManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Binary is not executable."])
            }
        }
    }

    private func extractCodexBinary(fromArchive archiveURL: URL, tempFolder: URL) throws -> URL {
        let extractionRoot = tempFolder.appendingPathComponent("extract-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractionRoot, withIntermediateDirectories: true)

        try runProcess(executablePath: "/usr/bin/tar", arguments: ["-xzf", archiveURL.path, "-C", extractionRoot.path])

        let enumerator = fileManager.enumerator(
            at: extractionRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var preferredCandidate: URL?

        while let item = enumerator?.nextObject() as? URL {
            guard fileManager.fileExists(atPath: item.path) else { continue }
            let name = item.lastPathComponent
            if name == "codex" || name.hasPrefix("codex-") {
                if fileManager.isExecutableFile(atPath: item.path) {
                    return item
                }
                preferredCandidate = preferredCandidate ?? item
            }
        }

        if let preferredCandidate {
            try ensureExecutable(at: preferredCandidate)
            return preferredCandidate
        }

        throw NSError(
            domain: "CodexBinaryManager",
            code: 1006,
            userInfo: [NSLocalizedDescriptionKey: "Cannot find Codex binary in archive."]
        )
    }

    private func runProcess(executablePath: String, arguments: [String]) throws {
        var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: executablePath))
        payload.arguments = arguments
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 120_000
        let result: SKProcessResult
        do {
            result = try SKProcessRunner.runSync(payload)
        } catch {
            throw NSError(
                domain: "CodexBinaryManager",
                code: 1007,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
        guard result.exitCode == 0 else {
            let message = Self.combinedOutput(stdout: result.stdout, stderr: result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "CodexBinaryManager",
                code: 1007,
                userInfo: [NSLocalizedDescriptionKey: message.nonEmpty ?? "Process failed."]
            )
        }
    }

    private func executableForCLI() -> String {
        if let managedPath = resolvedShimPathIfAvailable() {
            return "\"\(Self.escapeShell(managedPath))\""
        }
        return "codex"
    }

    private func hashForFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func detectCodexVersionInternal(at url: URL) -> String? {
        var payload = SKProcessPayload.executableURL(url)
        payload.arguments = ["--version"]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        do {
            let result = try SKProcessRunner.runSync(payload)
            let text = Self.combinedOutput(stdout: result.stdout, stderr: result.stderr)
            return Self.parseVersion(from: text)?.description
        } catch {
            return nil
        }
    }

    private func detectCodexVersionFromPATH() -> String? {
        var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: "/usr/bin/env"))
        payload.arguments = ["codex", "--version"]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        do {
            let result = try SKProcessRunner.runSync(payload)
            guard result.exitCode == 0 else { return nil }
            let text = Self.combinedOutput(stdout: result.stdout, stderr: result.stderr)
            return Self.parseVersion(from: text)?.description
        } catch {
            return nil
        }
    }

    private static func combinedOutput(stdout: String, stderr: String) -> String {
        if stdout.isEmpty { return stderr }
        if stderr.isEmpty { return stdout }
        return stdout + "\n" + stderr
    }

    private func compareXcodeVersion(_ lhs: String, _ rhs: String) -> Int {
        func parse(_ value: String) -> [Int] {
            value.split(separator: ".").map { Int($0) ?? 0 }
        }
        let left = parse(lhs)
        let right = parse(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r ? 1 : -1 }
        }
        if lhs == rhs { return 0 }
        return lhs > rhs ? 1 : -1
    }

    private func replaceWithSymlink(at path: URL, destination: String) throws {
        if fileManager.fileExists(atPath: path.path) || (try? path.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            try? fileManager.removeItem(at: path)
        }
        try fileManager.createSymbolicLink(atPath: path.path, withDestinationPath: destination)
    }

    private func resolvedShimPathIfAvailable() -> String? {
        let managedPath = binaryShimFile.url.path
        guard fileManager.fileExists(atPath: managedPath) else { return nil }
        if let destination = try? fileManager.destinationOfSymbolicLink(atPath: managedPath) {
            let baseURL = binaryShimFile.url.deletingLastPathComponent()
            let resolved = URL(fileURLWithPath: destination, relativeTo: baseURL).standardizedFileURL.path
            guard fileManager.fileExists(atPath: resolved) else { return nil }
        }
        return managedPath
    }

    private func resolveShellProfilePath(shellPath: String) -> String {
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()
        if shellName == "zsh" {
            return ".zshrc"
        }
        if shellName == "bash" {
            return ".bash_profile"
        }
        return ".profile"
    }

    private func isCodexBinInPATH() -> Bool {
        let codexBin = rootFolder.url.appendingPathComponent("bin", isDirectory: true).standardizedFileURL.path
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return path.split(separator: ":").contains { item in
            let expanded = expandTilde(String(item))
            let normalized = URL(fileURLWithPath: expanded).standardizedFileURL.path
            return normalized == codexBin
        }
    }

    private func expandTilde(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        return userHomeFolder.url.path + String(path.dropFirst())
    }

    private func displayPath(_ path: String) -> String {
        let home = userHomeFolder.url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func upsertPathBlock(_ contents: String, block: String) -> String {
        if let start = contents.range(of: Self.pathMarkerStart),
           let end = contents.range(of: Self.pathMarkerEnd)
        {
            let replaceRange = start.lowerBound..<end.upperBound
            return contents.replacingCharacters(in: replaceRange, with: block)
        }

        if contents.contains(pathExportLine) {
            return contents
        }

        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return block + "\n"
        }
        return trimmed + "\n\n" + block + "\n"
    }

    private func applyXcodeAgentLinks(to selectedBinary: URL) throws {
        guard fileManager.fileExists(atPath: xcodeAgentsVersionsFolder.url.path) else { return }
        let entries = try fileManager.contentsOfDirectory(
            at: xcodeAgentsVersionsFolder.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for entry in entries {
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let codexTarget = entry.appendingPathComponent("codex")

            let backupDir = rootFolder.url.appendingPathComponent("backups/xcode/\(entry.lastPathComponent)", isDirectory: true)
            let backupFile = backupDir.appendingPathComponent("codex.original")
            if fileManager.fileExists(atPath: codexTarget.path) && !fileManager.fileExists(atPath: backupFile.path) {
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
                try? fileManager.copyItem(at: codexTarget, to: backupFile)
            }

            try? fileManager.removeItem(at: codexTarget)
            try fileManager.createSymbolicLink(atPath: codexTarget.path, withDestinationPath: selectedBinary.path)
        }
    }

    private func syncPreferredModelIfNeeded(manifest: CodexBinaryManifest) throws {
        guard manifest.syncModelOnSwitch else { return }
        guard let model = manifest.preferredModel?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty else { return }
        try writeModelToConfig(model, file: xcodeCodexConfigFile)
    }

    private func writeModelToConfig(_ model: String, file: STFile) throws {
        guard !model.isEmpty else { return }
        try writeConfigValue(key: "model", value: model, file: file)
    }

    private func removeModelFromConfig(file: STFile) throws {
        try removeConfigValue(key: "model", file: file)
    }

    private func writeConfigValue(key: String, value: String, file: STFile) throws {
        guard !key.isEmpty else { return }
        let parent = file.url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        let original = (try? String(contentsOf: file.url, encoding: .utf8)) ?? ""
        let lines = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        let assignLine = "\(key) = \"\(escaped)\""

        var replaced = false
        let rewritten = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equalIndex = trimmed.firstIndex(of: "=") else { return line }
            let existingKey = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if existingKey == key {
                replaced = true
                return assignLine
            }
            return line
        }

        let output: String
        if replaced {
            output = rewritten.joined(separator: "\n")
        } else if original.isEmpty {
            output = assignLine + "\n"
        } else {
            output = original + (original.hasSuffix("\n") ? "" : "\n") + assignLine + "\n"
        }
        try output.write(to: file.url, atomically: true, encoding: .utf8)
    }

    private func removeConfigValue(key: String, file: STFile) throws {
        guard !key.isEmpty else { return }
        let url = file.url
        guard fileManager.fileExists(atPath: url.path) else { return }
        let original = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let lines = original.split(separator: "\n", omittingEmptySubsequences: false)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equalIndex = trimmed.firstIndex(of: "=") else { return true }
            let existingKey = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return existingKey != key
        }
        let output = filtered.map(String.init).joined(separator: "\n")
        try output.write(to: url, atomically: true, encoding: .utf8)
    }

    private func highestInstalledVersion(in manifest: CodexBinaryManifest) -> String? {
        let candidates = manifest.versions.map(\.detectedVersion).filter { Self.parseVersion(from: $0) != nil }
        return candidates.max { Self.compareVersion($0, $1) < 0 }
    }

    public func fetchRemoteReleases(includePrerelease: Bool) async throws -> [CodexRemoteRelease] {
        let url = URL(string: "https://api.github.com/repos/openai/codex/releases?per_page=30")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Nolon/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        let archNeedle = Self.currentArchitectureNeedle()

        var output: [CodexRemoteRelease] = []
        for release in releases {
            guard !release.draft else { continue }
            if !includePrerelease, release.prerelease { continue }
            guard release.tagName.hasPrefix("rust-v") else { continue }
            let version = String(release.tagName.dropFirst("rust-v".count))
            if !includePrerelease, !Self.isStableVersion(version) { continue }
            guard let asset = release.assets.first(where: { $0.name.contains(archNeedle) && $0.name.hasSuffix(".tar.gz") }) else {
                continue
            }
            output.append(
                CodexRemoteRelease(
                    tag: release.tagName,
                    version: version,
                    assetURL: asset.browserDownloadURL,
                    isPrerelease: release.prerelease
                )
            )
        }
        return output
    }

    private func fetchLatestRustRelease(includePrerelease: Bool) async throws -> (tag: String, version: String, assetURL: URL)? {
        let releases = try await fetchRemoteReleases(includePrerelease: includePrerelease)
        guard let first = releases.first else { return nil }
        return (first.tag, first.version, first.assetURL)
    }

    private static func currentArchitectureNeedle() -> String {
        #if arch(arm64)
        return "aarch64-apple-darwin"
        #else
        return "x86_64-apple-darwin"
        #endif
    }

    public static func compareVersion(_ lhsRaw: String, _ rhsRaw: String) -> Int {
        guard let lhs = parseVersion(from: lhsRaw), let rhs = parseVersion(from: rhsRaw) else {
            return lhsRaw.compare(rhsRaw, options: .numeric).rawValue
        }
        if lhs < rhs { return -1 }
        if lhs > rhs { return 1 }
        return 0
    }

    public static func isStableVersion(_ raw: String) -> Bool {
        guard let version = parseVersion(from: raw) else { return false }
        return version.prereleaseIdentifiers.isEmpty
    }

    private static func makeVersionID(version: String, hash: String) -> String {
        let safeVersion = parseVersion(from: version)?.description ?? "unknown"
        return "v\(safeVersion)-\(hash.prefix(8))"
    }

    static func parseVersion(from raw: String) -> STVersion? {
        STVersion(string: raw)
    }

    private static func normalizedEnvironment(_ env: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (rawKey, rawValue) in env {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty, isValidEnvironmentKey(key), !isReservedEnvironmentKey(key) else { continue }
            normalized[key] = value
        }
        return normalized
    }

    private static func escapeShell(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func isValidEnvironmentKey(_ key: String) -> Bool {
        let pattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isReservedEnvironmentKey(_ key: String) -> Bool {
        key.uppercased() == "CODEX_HOME"
    }

}

public nonisolated struct CodexDownloadProgress: Sendable {
    public let fractionCompleted: Double?
    public let completedBytes: Int64?
    public let totalBytes: Int64?

    public init(fractionCompleted: Double?, completedBytes: Int64?, totalBytes: Int64?) {
        self.fractionCompleted = fractionCompleted
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }
}

public nonisolated struct CodexRemoteRelease: Sendable, Identifiable, Hashable {
    public let id: String
    public let tag: String
    public let version: String
    public let assetURL: URL
    public let isPrerelease: Bool

    public init(tag: String, version: String, assetURL: URL, isPrerelease: Bool) {
        self.id = tag
        self.tag = tag
        self.version = version
        self.assetURL = assetURL
        self.isPrerelease = isPrerelease
    }
}

private nonisolated struct GitHubRelease: Decodable {
    let tagName: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case assets
    }
}

private nonisolated struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private nonisolated extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}


nonisolated extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
