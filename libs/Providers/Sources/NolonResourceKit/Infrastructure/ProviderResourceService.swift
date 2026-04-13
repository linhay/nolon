import Foundation
import ProviderCatalog
import STFilePath

public enum ProviderResourceKind: String, Sendable, CaseIterable {
    case workflow
    case rule
    case agent
}

public enum ProviderResourceState: String, Sendable, Equatable {
    case installed
    case orphaned
    case broken
}

public extension ProviderResourceState {
    var healthState: ResourceHealthState {
        switch self {
        case .installed: return .installed
        case .orphaned: return .orphaned
        case .broken: return .broken
        }
    }

    init(_ healthState: ResourceHealthState) {
        switch healthState {
        case .installed: self = .installed
        case .orphaned: self = .orphaned
        case .broken: self = .broken
        }
    }
}

public enum ProviderAgentKind: String, Sendable, Equatable {
    case base
    case override
}

public struct ProviderResourceItem: Sendable, Equatable, Hashable {
    public let kind: ProviderResourceKind
    public let id: String
    public let name: String
    public let path: String
    public let preview: String
    public let relativePath: String?
    public let state: ProviderResourceState
    public let source: WorkflowSourceKind?
    public let agentKind: ProviderAgentKind?

    public init(
        kind: ProviderResourceKind,
        id: String,
        name: String,
        path: String,
        preview: String,
        relativePath: String? = nil,
        state: ProviderResourceState = .installed,
        source: WorkflowSourceKind? = nil,
        agentKind: ProviderAgentKind? = nil
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.path = path
        self.preview = preview
        self.relativePath = relativePath
        self.state = state
        self.source = source
        self.agentKind = agentKind
    }
}

public enum ProviderResourceDraftKind: Sendable, Equatable {
    case workflow
    case rule
    case agentBase
    case agentOverride
}

public final class ProviderResourceService: @unchecked Sendable {
    private let fileManager: FileManager
    private let nolonManager: NolonManager

    public init(
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
    }

    public func scanWorkflows(provider: Provider) -> [ProviderResourceItem] {
        let folder = STFolder(provider.workflowPath)
        guard folder.isExists else { return [] }
        let names = (try? fileManager.contentsOfDirectory(atPath: folder.url.path)) ?? []
        return names
            .filter { !$0.hasPrefix(".") && $0.lowercased().hasSuffix(".md") }
            .compactMap { name in
                let filePath = folder.subpath(name).url.path
                return parseWorkflow(atPath: filePath, idOverride: String(name.dropLast(3)))
            }
            .sorted { lhs, rhs in
                if lhs.state == rhs.state {
                    return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
                }
                return stateOrder(lhs.state) < stateOrder(rhs.state)
            }
    }

    public func scanRules(provider: Provider) -> [ProviderResourceItem] {
        guard isCodexProvider(provider) else { return [] }
        let baseDirectory = provider.codexRulesURL
        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let folder = STFolder(baseDirectory)
        guard folder.isExists else { return [] }

        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [ProviderResourceItem] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }
            guard url.pathExtension.lowercased() == "rules" else { continue }

            if url.lastPathComponent.hasPrefix(".") { continue }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let canonicalPath = url.resolvingSymlinksInPath().standardizedFileURL.path
            let relativePath: String
            if canonicalPath.hasPrefix(basePath + "/") {
                relativePath = String(canonicalPath.dropFirst(basePath.count + 1))
            } else {
                relativePath = url.lastPathComponent
            }
            let id = relativePath.replacingOccurrences(of: ".rules", with: "")
            items.append(
                ProviderResourceItem(
                    kind: .rule,
                    id: id,
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    preview: firstNonEmptyLine(from: content),
                    relativePath: relativePath,
                    state: .installed,
                    source: nil,
                    agentKind: nil
                )
            )
        }

        return items.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    public func scanAgentDocs(provider: Provider) -> [ProviderResourceItem] {
        let targets = agentDocTargets(for: provider)
        guard !targets.isEmpty else { return [] }
        var items: [ProviderResourceItem] = []

        for target in targets {
            if STFile(target.url).isExists, let item = parseAgentDoc(url: target.url, kind: target.kind) {
                items.append(item)
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.agentKind == rhs.agentKind {
                return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
            }
            return lhs.agentKind == .override
        }
    }

    public func parseWorkflow(atPath path: String, idOverride: String? = nil) -> ProviderResourceItem? {
        let url = URL(fileURLWithPath: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let resourceID = idOverride.flatMap(Self.nonEmptyTrimmed(_:)) ?? fileName
        let metadata = FrontmatterParser.parseMetadata(from: content)
        guard let description = metadata["description"].flatMap(Self.nonEmptyTrimmed(_:)) else { return nil }
        let displayName = metadata["name"].flatMap(Self.nonEmptyTrimmed(_:)) ?? fileName

        let linkPath = url.path
        let filePath = STPath(url)
        let state: ProviderResourceState
        let source: WorkflowSourceKind

        if filePath.isSymbolicLink {
            let destination = (try? fileManager.destinationOfSymbolicLink(atPath: linkPath)) ?? ""
            let resolved = WorkflowSourceResolver.resolveSymlinkDestination(
                linkPath: linkPath,
                destination: destination
            )
            if !STPath(resolved).isExists {
                state = .broken
                source = .unknown
            } else {
                source = WorkflowSourceResolver.resolve(
                    workflowPath: linkPath,
                    resolvedPath: resolved,
                    nolonManager: nolonManager
                )
                state = source == .unknown ? .orphaned : .installed
            }
        } else {
            let inferred = inferWorkflowSourceByID(resourceID)
            source = inferred
            state = inferred == .unknown ? .orphaned : .installed
        }

        return ProviderResourceItem(
            kind: .workflow,
            id: resourceID,
            name: displayName,
            path: linkPath,
            preview: description,
            relativePath: nil,
            state: state,
            source: source,
            agentKind: nil
        )
    }

    public func deleteResource(atPath path: String) throws {
        try STPath(path).deleteIncludingBrokenSymlink()
    }

    @discardableResult
    public func copyAgentDocToNolon(atPath path: String) throws -> URL {
        try transferAgentDocToNolon(atPath: path, mode: .copy)
    }

    @discardableResult
    public func moveAgentDocToNolon(atPath path: String) throws -> URL {
        try transferAgentDocToNolon(atPath: path, mode: .move)
    }

    public func deleteWorkflow(workflowID: String, provider: Provider) throws {
        let workflowFolder = STFolder(provider.workflowPath)
        let primary = workflowFolder.file("\(workflowID).md")
        if primary.isExists || primary.isSymbolicLink {
            try primary.deleteIncludingBrokenSymlink()
            return
        }
        let fallback = workflowFolder.file(workflowID)
        if fallback.isExists || fallback.isSymbolicLink {
            try fallback.deleteIncludingBrokenSymlink()
        }
    }

    public func createDraft(provider: Provider, kind: ProviderResourceDraftKind) throws -> URL {
        switch kind {
        case .workflow:
            let folder = STFolder(provider.workflowPath)
            _ = folder.createIfNotExists()
            var index = 1
            var candidate = folder.file("new-workflow-\(index).md")
            while candidate.isExists {
                index += 1
                candidate = folder.file("new-workflow-\(index).md")
            }
            try "".write(to: candidate.url, atomically: true, encoding: .utf8)
            return candidate.url
        case .rule:
            let folder = provider.codexRulesFolder
            _ = folder.createIfNotExists()
            var index = 1
            var candidate = folder.file("new-rule-\(index).rules")
            while candidate.isExists {
                index += 1
                candidate = folder.file("new-rule-\(index).rules")
            }
            try "".write(to: candidate.url, atomically: true, encoding: .utf8)
            return candidate.url
        case .agentBase:
            guard let baseURL = preferredBaseAgentDocURL(for: provider) else {
                throw NSError(
                    domain: "ProviderResourceService",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Provider does not support AGENTS.md draft creation."]
                )
            }
            _ = STFolder(baseURL.deletingLastPathComponent()).createIfNotExists()
            if !STFile(baseURL).isExists {
                try "".write(to: baseURL, atomically: true, encoding: .utf8)
            }
            return baseURL
        case .agentOverride:
            _ = provider.codexHomeFolder.createIfNotExists()
            if !provider.codexAgentsOverrideFile.isExists {
                try "".write(to: provider.codexAgentsOverrideFile.url, atomically: true, encoding: .utf8)
            }
            return provider.codexAgentsOverrideFile.url
        }
    }

    private func parseAgentDoc(url: URL, kind: ProviderAgentKind) -> ProviderResourceItem? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return ProviderResourceItem(
            kind: .agent,
            id: url.path,
            name: url.lastPathComponent,
            path: url.path,
            preview: firstNonEmptyLine(from: content),
            relativePath: nil,
            state: .installed,
            source: nil,
            agentKind: kind
        )
    }

    private func inferWorkflowSourceByID(_ workflowID: String) -> WorkflowSourceKind {
        let userPath = nolonManager.userWorkflowsFolder.file("\(workflowID).md").url.path
        if STFile(userPath).isExists { return .user }
        let skillPath = nolonManager.generatedWorkflowsFolder.file("\(workflowID).md").url.path
        if STFile(skillPath).isExists { return .skill }
        let mcpPath = nolonManager.mcpsWorkflowsFolder.file("\(workflowID).md").url.path
        if STFile(mcpPath).isExists { return .mcp }
        return .unknown
    }

    private func isCodexProvider(_ provider: Provider) -> Bool {
        provider.templateId == "codex" || provider.templateId == "codexXcode"
    }

    private func isClaudeProvider(_ provider: Provider) -> Bool {
        provider.templateId == ProviderTemplate.claudeCode.rawValue
    }

    private func firstNonEmptyLine(from content: String) -> String {
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    private func stateOrder(_ state: ProviderResourceState) -> Int {
        switch state {
        case .broken: return 0
        case .orphaned: return 1
        case .installed: return 2
        }
    }
    private static func nonEmptyTrimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum AgentTransferMode {
        case copy
        case move
    }

    private func transferAgentDocToNolon(atPath path: String, mode: AgentTransferMode) throws -> URL {
        let sourceURL = URL(fileURLWithPath: path).standardizedFileURL
        let sourcePath = sourceURL.path
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw NSError(
                domain: "ProviderResourceService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Source AGENTS file not found."]
            )
        }

        let destinationFolder = nolonManager.agentsURL.standardizedFileURL
        _ = STFolder(destinationFolder).createIfNotExists()
        let destinationURL = uniqueAgentDestinationURL(
            in: destinationFolder,
            sourceName: sourceURL.lastPathComponent
        )

        switch mode {
        case .copy:
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        case .move:
            if sourcePath == destinationURL.path {
                return destinationURL
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }

        return destinationURL
    }

    private func uniqueAgentDestinationURL(in folder: URL, sourceName: String) -> URL {
        let source = URL(fileURLWithPath: sourceName)
        let ext = source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent

        var candidate = folder.appendingPathComponent(sourceName)
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = "-copy-\(index)"
            let fileName: String
            if ext.isEmpty {
                fileName = base + suffix
            } else {
                fileName = "\(base)\(suffix).\(ext)"
            }
            candidate = folder.appendingPathComponent(fileName)
            index += 1
        }
        return candidate
    }

    private struct AgentDocTarget {
        let url: URL
        let kind: ProviderAgentKind
    }

    private func agentDocTargets(for provider: Provider) -> [AgentDocTarget] {
        if isCodexProvider(provider) {
            return [
                AgentDocTarget(url: provider.codexAgentsFileURL, kind: .base),
                AgentDocTarget(url: provider.codexAgentsOverrideFile.url, kind: .override),
            ]
        }

        if isClaudeProvider(provider) {
            return [AgentDocTarget(url: provider.claudeInstructionsFileURL, kind: .base)]
        }

        if provider.templateId == "opencode" {
            let baseURL = URL(fileURLWithPath: provider.defaultSkillsPath)
                .deletingLastPathComponent()
                .appendingPathComponent("AGENTS.md")
            return [AgentDocTarget(url: baseURL, kind: .base)]
        }

        if provider.templateId == "copilot" {
            var targets: [AgentDocTarget] = []
            let homeURL = URL(fileURLWithPath: provider.defaultSkillsPath)
                .deletingLastPathComponent()
                .appendingPathComponent("AGENTS.md")
            targets.append(AgentDocTarget(url: homeURL, kind: .base))

            let env = ProcessInfo.processInfo.environment["COPILOT_CUSTOM_INSTRUCTIONS_DIRS"] ?? ""
            let directories = env
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for directory in directories {
                let expanded = (directory as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded).appendingPathComponent("AGENTS.md")
                targets.append(AgentDocTarget(url: url, kind: .base))
            }

            var deduped: [AgentDocTarget] = []
            var seen = Set<String>()
            for target in targets {
                let path = target.url.standardizedFileURL.path
                guard seen.insert(path).inserted else { continue }
                deduped.append(target)
            }
            return deduped
        }

        return []
    }

    private func preferredBaseAgentDocURL(for provider: Provider) -> URL? {
        agentDocTargets(for: provider).first(where: { $0.kind == .base })?.url
    }
}
