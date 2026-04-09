import Foundation
import ProviderCatalog
import NolonResourceKit
import ProviderUsage
import CodexBarProviderCatalog
import SKProcessRunner
import STFilePath

extension NolonCoreCLIRunner {
    func formatSkillsAddText(_ result: NolonSkillsAddResult) -> String {
        var lines: [String] = []
        if result.dryRun {
            lines.append("[DRY-RUN] No changes applied")
        }
        lines.append("skill: \(result.slug) (\(result.source.rawValue))")
        lines.append("cache: \(result.cachedPath)")
        lines.append("install_method: \(result.installMethod.rawValue)")
        if result.dryRun {
            lines.append("status: dry-run (no cache writes, no installation)")
        } else {
            lines.append("status: apply")
        }
        if let scope = Self.makeInstallScopeLabel(targets: result.targets) {
            lines.append("scope: \(scope)")
        }
        if result.dryRun {
            lines.append("result: planned=\(result.successCount), invalid=\(result.failureCount)")
        } else {
            lines.append("result: installed=\(result.successCount), failed=\(result.failureCount)")
        }
        if !result.warnings.isEmpty {
            lines.append("warnings:")
            lines.append(contentsOf: result.warnings.map { "- \($0)" })
        }
        if let safetyWarning = Self.makeMultiProviderSafetyWarning(targets: result.targets, dryRun: result.dryRun) {
            lines.append("safety:")
            lines.append("- \(safetyWarning)")
        }
        lines.append("targets:")
        lines.append(contentsOf: result.targets.map { target in
            let prefix: String
            switch target.status {
            case .installed:
                prefix = "[OK]"
            case .planned:
                prefix = "[PLAN]"
            case .failed:
                prefix = "[FAIL]"
            }
            if target.status == .installed || target.status == .planned {
                return "\(prefix) \(target.providerID) -> \(target.installedPath ?? "-")"
            }
            return "\(prefix) \(target.providerID) -> - (\(target.errorMessage ?? "install failed"))"
        })
        return lines.joined(separator: "\n")
    }

    func formatWorkflowBindText(
        result: NolonResourceInstallResult,
        sourceLabel: String,
        sourceID: String
    ) -> String {
        [
            "workflow bind: success",
            "source: \(sourceLabel):\(sourceID)",
            "name: \(result.resourceName)",
            "global: \(result.sourcePath)",
            "target: \(result.targetPath)",
            "install_method: \(result.installMethod.rawValue)",
        ].joined(separator: "\n")
    }

    func formatWorkflowUnbindText(
        result: NolonResourceUninstallResult,
        sourceLabel: String,
        sourceID: String
    ) -> String {
        [
            "workflow unbind: \(result.removed ? "success" : "noop")",
            "source: \(sourceLabel):\(sourceID)",
            "name: \(result.resourceName)",
            "target: \(result.targetPath)",
            "removed: \(result.removed)",
        ].joined(separator: "\n")
    }

    func formatMcpServerListText(result: NolonMcpServerListResult) -> String {
        var lines: [String] = []
        lines.append("mcp server list")
        lines.append("provider: \(result.providerID)")
        lines.append("config: \(result.configPath)")
        lines.append("servers_total: \(result.items.count)")
        if result.items.isEmpty {
            lines.append("servers: (empty)")
            return lines.joined(separator: "\n")
        }
        lines.append("")
        lines.append("[servers]")
        for item in result.items {
            lines.append("- name: \(item.name)")
            lines.append("  enabled: \(item.enabled)")
            if let url = item.url, !url.isEmpty { lines.append("  url: \(url)") }
            if let command = item.command, !command.isEmpty { lines.append("  command: \(command)") }
            if let args = item.args, !args.isEmpty { lines.append("  args: \(args.joined(separator: " "))") }
            if let env = item.env, !env.isEmpty {
                let values = env.keys.sorted().map { "\($0)=\(env[$0] ?? "")" }.joined(separator: ", ")
                lines.append("  env: \(values)")
            }
        }
        return lines.joined(separator: "\n")
    }

    func formatMcpServerMutationText(result: NolonMcpServerMutationResult) -> String {
        [
            "mcp server mutation: success",
            "provider: \(result.providerID)",
            "config: \(result.configPath)",
            "name: \(result.name)",
            "action: \(result.action)",
        ].joined(separator: "\n")
    }

    func formatMcpCacheMigrateText(result: NolonMcpCacheMigrateResult, overwrite: Bool) -> String {
        [
            "mcp cache migrate: success",
            "provider: \(result.providerID)",
            "config: \(result.configPath)",
            "overwrite: \(overwrite)",
            "migrated: \(result.migrated)",
            "updated: \(result.updated)",
            "skipped: \(result.skipped)",
        ].joined(separator: "\n")
    }

    func formatMcpCacheStatusText(result: NolonMcpCacheStatusResult, filterName: String?) -> String {
        var lines: [String] = []
        lines.append("mcp cache status")
        lines.append("provider: \(result.providerID)")
        lines.append("config: \(result.configPath)")
        if let filterName, !filterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("filter: \(filterName)")
        }
        lines.append("servers_total: \(result.items.count)")
        if result.items.isEmpty {
            lines.append("servers: (empty)")
            return lines.joined(separator: "\n")
        }
        lines.append("")
        lines.append("[servers]")
        for item in result.items {
            lines.append("- name: \(item.name)")
            lines.append("  state: \(item.state.rawValue)")
            lines.append("  cache: \(item.cachePath)")
        }
        return lines.joined(separator: "\n")
    }

    static func makeInstallScopeLabel(targets: [NolonSkillsAddTargetResult]) -> String? {
        let providerIDs = Array(Set(targets.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard providerIDs.count > 1 else {
            return nil
        }
        return "multi-provider (\(providerIDs.count): \(providerIDs.joined(separator: ",")))"
    }

    static func makeMultiProviderSafetyWarning(
        targets: [NolonSkillsAddTargetResult],
        dryRun: Bool
    ) -> String? {
        let providerIDs = Array(Set(targets.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard providerIDs.count > 1 else {
            return nil
        }
        let providerList = providerIDs.joined(separator: ",")
        if dryRun {
            return "未指定 --provider：当前预览将分发到 \(providerIDs.count) 个 providers（\(providerList)）。如仅安装单个目标，请使用 --provider <provider-id>。"
        }
        return "[WARN] 未指定 --provider：本次将安装到 \(providerIDs.count) 个 providers（\(providerList)）。如仅安装单个目标，请使用 --provider <provider-id>；建议先执行 --dry-run。"
    }

    func formatSkillsRepoListText(
        repositoriesRoot: String,
        repositories: [NolonLocalRepositorySummary],
        verbose: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("repositories_root: \(repositoriesRoot)")
        if repositories.isEmpty {
            lines.append("未发现本地仓库")
            return lines.joined(separator: "\n")
        }

        if verbose {
            let rows = repositories.map {
                [$0.name, $0.path, "\($0.skillsDirectoryCount)", "\($0.workflowCount)", "\($0.mcpCount)"]
            }
            lines.append(contentsOf: renderTable(headers: ["repo", "path", "skills", "workflows", "mcps"], rows: rows))
        } else {
            let rows = repositories.map {
                [$0.name, "\($0.skillsDirectoryCount)", "\($0.workflowCount)", "\($0.mcpCount)"]
            }
            lines.append(contentsOf: renderTable(headers: ["repo", "skills", "workflows", "mcps"], rows: rows))
        }
        return lines.joined(separator: "\n")
    }

    func formatSkillsListText(_ result: NolonSkillsListResult, verbose: Bool, showFixes: Bool) -> String {
        let presenter = ResourceListTextPresenter()
        return presenter.render(
            makePresentationInput(
                kind: .skill,
                result: result,
                verbose: verbose,
                showFixes: showFixes
            )
        )
    }

    func formatSkillsSearchText(_ result: NolonRemoteListResult) -> String {
        if result.items.isEmpty {
            return """
            未找到匹配 skill
            提示: 使用 `nolon skills sync --source <owner/repo>` 同步本地仓库后重试，或更换关键词。
            """
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let queryValue = result.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selection = SearchPresentationPolicy.select(
            query: queryValue,
            items: result.items,
            maxDisplayCount: 10,
            slug: \.slug
        )
        let exactMatch = selection.exactMatch
        let displayPool = selection.displayed
        let alternativeCandidates = selection.alternatives
        let showSummary = displayPool.count <= 8
        let queryPart = queryValue.isEmpty ? "" : " (query: \(queryValue))"
        let headline: String
        if let exactMatch {
            headline = "精确命中: \(exactMatch.slug)\(queryPart), candidates: \(result.items.count)"
        } else {
            headline = "匹配结果: \(result.items.count)\(queryPart)"
        }
        let maxDisplay = 10
        let displayedItems = Array(displayPool.prefix(maxDisplay))
        let lines = displayedItems.enumerated().map { index, item in
            let version = item.latestVersion ?? "-"
            let updated = item.updatedAt.map { formatUpdatedDate($0, formatter: formatter) } ?? "-"
            var itemLines: [String] = [
                "[\(index + 1)] \(item.slug)",
                "  version: \(version)",
                "  updated: \(updated)",
            ]
            if showSummary, let summary = compactSummary(item.summary, maxLength: 140) {
                itemLines.append("  summary: \(summary)")
            }
            return itemLines.joined(separator: "\n")
        }.joined(separator: "\n\n")
        let currentQueryExample = queryValue.isEmpty ? "<keyword>" : queryValue
        var hintParts: [String] = []
        if !showSummary {
            hintParts.append("已省略 summary（将 `--limit` 设为 8 或更小可查看摘要）")
        }
        if exactMatch == nil, result.items.count > displayedItems.count {
            hintParts.append("仅展示前 \(displayedItems.count) 条（可增大 `--limit` 查看更多）")
        }
        let hintBlock = hintParts.isEmpty ? "" : "提示: " + hintParts.joined(separator: "；") + "。\n"
        let alternativesBlock: String = {
            guard !alternativeCandidates.isEmpty else { return "" }
            let names = alternativeCandidates.prefix(5).map(\.slug).joined(separator: ", ")
            let suffix = alternativeCandidates.count > 5 ? " 等" : ""
            return "其他候选(\(alternativeCandidates.count)): \(names)\(suffix)\n"
        }()
        let installLines: [String]
        if let exactMatch {
            installLines = [
                "- nolon skills add \(exactMatch.slug) --provider codex --dry-run",
            ]
        } else if result.items.count == 1, let first = result.items.first {
            installLines = [
                "- nolon skills add \(first.slug) --provider codex --dry-run",
            ]
        } else {
            installLines = [
                "- nolon skills add <slug> --provider codex --dry-run",
                "- nolon skills search \(currentQueryExample) --install --pick <序号> --provider codex --dry-run",
            ]
        }
        let installBlock = installLines.joined(separator: "\n")
        return """
        \(headline)
        \(hintBlock)\(alternativesBlock)安装:
        \(installBlock)
        \(lines)
        """
    }

    func formatResourceSearchText(kind: NolonResourceKind, result: NolonRemoteListResult) -> String {
        let presenter = RemoteSearchTextPresenter()
        let mappedKind: RemoteSearchPresentationKind = (kind == .workflow) ? .workflow : .mcp
        let input = RemoteSearchPresentationInput(
            kind: mappedKind,
            baseURL: result.baseURL,
            query: result.query,
            items: result.items.map {
                RemoteSearchPresentationItem(
                    slug: $0.slug,
                    summary: $0.summary,
                    latestVersion: $0.latestVersion,
                    updatedAt: $0.updatedAt
                )
            }
        )
        return presenter.render(input)
    }

    func formatResourceAddText(kind: NolonResourceKind, result: NolonSkillsAddResult) -> String {
        var lines: [String] = []
        if result.dryRun {
            lines.append("[DRY-RUN] No changes applied")
        }
        lines.append("\(kind.rawValue): \(result.slug) (\(result.source.rawValue))")
        lines.append("cache: \(result.cachedPath)")
        lines.append("install_method: \(result.installMethod.rawValue)")
        lines.append("status: \(result.dryRun ? "dry-run (no cache writes, no installation)" : "apply")")
        if let scope = Self.makeInstallScopeLabel(targets: result.targets) {
            lines.append("scope: \(scope)")
        }
        if result.dryRun {
            lines.append("result: planned=\(result.successCount), invalid=\(result.failureCount)")
        } else {
            lines.append("result: installed=\(result.successCount), failed=\(result.failureCount)")
        }
        if !result.warnings.isEmpty {
            lines.append("warnings:")
            lines.append(contentsOf: result.warnings.map { "- \($0)" })
        }
        if let safety = Self.makeMultiProviderSafetyWarning(targets: result.targets, dryRun: result.dryRun) {
            lines.append("safety:")
            lines.append("- \(safety)")
        }
        lines.append(contentsOf: result.targets.map { target in
            let label: String
            switch target.status {
            case .planned:
                label = "[PLAN]"
            case .installed:
                label = "[OK]"
            case .failed:
                label = "[FAIL]"
            }
            var line = "\(label) \(target.providerID) -> \(target.installedPath ?? "-")"
            if let error = target.errorMessage, !error.isEmpty {
                line += " (\(error))"
            }
            return line
        })
        return lines.joined(separator: "\n")
    }

    func formatResourceListText(
        kind: NolonResourceKind,
        _ result: NolonSkillsListResult,
        verbose: Bool,
        showFixes: Bool
    ) -> String {
        let presenter = ResourceListTextPresenter()
        let mappedKind: ResourceListPresentationKind = {
            switch kind {
            case .workflow: return .workflow
            case .mcp: return .mcp
            }
        }()
        return presenter.render(
            makePresentationInput(
                kind: mappedKind,
                result: result,
                verbose: verbose,
                showFixes: showFixes
            )
        )
    }

    func makePresentationInput(
        kind: ResourceListPresentationKind,
        result: NolonSkillsListResult,
        verbose: Bool,
        showFixes: Bool
    ) -> ResourceListPresentationInput {
        ResourceListPresentationInput(
            kind: kind,
            providerFilter: result.providerFilter,
            stateFilter: result.stateFilter.map(toPresentationState),
            items: result.items.map { item in
                ResourceListPresentationItem(
                    providerID: item.providerID,
                    resourceID: item.skillID,
                    state: toPresentationState(item.state),
                    path: item.path,
                    originDescription: item.origin.flatMap { origin in
                        guard origin.sourceType != .unknown else { return nil }
                        return Self.originDescriptionForDisplay(origin)
                    }
                )
            },
            summary: ResourceListPresentationSummary(
                providersScanned: result.summary.providerCount,
                providersMatched: matchedProvidersCount(for: result),
                totalCount: result.summary.itemCount,
                installedCount: result.summary.installedCount,
                orphanedCount: result.summary.orphanedCount,
                brokenCount: result.summary.brokenCount
            ),
            verbose: verbose,
            showFixes: showFixes
        )
    }

    func toPresentationState(_ state: NolonProviderSkillStateKind) -> ResourceListPresentationState {
        switch state {
        case .installed: return .installed
        case .orphaned: return .orphaned
        case .broken: return .broken
        }
    }

    static func buildResourceFixCommands(
        kind: NolonResourceKind,
        items: [NolonSkillsListItem]
    ) -> (simple: String, detailed: [String]) {
        let planItems = items.compactMap { toRepairItemIfNeeded($0) }
        let plan = ResourceRepairPlanner.plan(
            kind: toRepairResourceKind(kind),
            items: planItems
        )
        let detailed = plan.steps.flatMap(\.commands)
        return (simple: detailed.first ?? "", detailed: detailed)
    }

    static func buildSkillFixCommands(
        items: [NolonSkillsListItem]
    ) -> (simple: String, detailed: [String]) {
        let planItems = items.compactMap { toRepairItemIfNeeded($0) }
        let plan = ResourceRepairPlanner.plan(kind: .skill, items: planItems)
        let detailed = plan.steps.flatMap(\.commands)
        return (simple: detailed.first ?? "", detailed: detailed)
    }

    static func toRepairResourceKind(_ kind: NolonResourceKind) -> RepairResourceKind {
        switch kind {
        case .workflow:
            return .workflow
        case .mcp:
            return .mcp
        }
    }

    static func toRepairItemIfNeeded(_ item: NolonSkillsListItem) -> RepairItem? {
        switch item.state {
        case .orphaned, .broken:
            return toRepairItem(item)
        case .installed:
            return nil
        }
    }

    static func toRepairItem(_ item: NolonSkillsListItem) -> RepairItem {
        let state: RepairStateKind = item.state == .broken ? .broken : .orphaned
        return RepairItem(providerID: item.providerID, resourceID: item.skillID, state: state)
    }

    func matchedProvidersCount(for result: NolonSkillsListResult) -> Int {
        if let filter = result.providerFilter, !filter.isEmpty {
            return 1
        }
        return Set(result.items.map(\.providerID)).count
    }

    func formatUpdatedDate(_ date: Date, formatter: DateFormatter) -> String {
        let rendered = formatter.string(from: date)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        guard target > today else { return rendered }
        let dayDiff = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        guard dayDiff > 0 else { return rendered }
        return "\(rendered) (future +\(dayDiff)d)"
    }

    func compactSummary(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let compact = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        guard compact.count > maxLength else { return compact }
        let prefix = compact.prefix(max(0, maxLength - 3))
        return "\(prefix)..."
    }

    static func originDescriptionForDisplay(_ origin: NolonResourceOrigin) -> String {
        let sourceLabel = localizedSourceTypeLabel(origin.sourceType)
        let compactRef = compactSourceReference(origin.sourceRef)
        let inferredSuffix = origin.metadata["inferred"] == "true" ? " [推断]" : ""
        return "\(sourceLabel)(\(compactRef))\(inferredSuffix)"
    }

    static func localizedSourceTypeLabel(_ type: NolonResourceSourceType) -> String {
        switch type {
        case .local:
            return "本地"
        case .remote:
            return "远端"
        case .fromSkill:
            return "技能"
        case .fromWorkflow:
            return "工作流"
        case .fromMcp:
            return "MCP"
        case .unknown:
            return "未知"
        }
    }

    static func compactSourceReference(_ raw: String, maxLength: Int = 72) -> String {
        guard raw.count > maxLength else { return raw }
        let home = NSString(string: NSHomeDirectory()).expandingTildeInPath
        var normalized = raw
        if normalized.hasPrefix(home) {
            normalized = "~" + normalized.dropFirst(home.count)
        }
        guard normalized.count > maxLength else { return normalized }

        if let anchorIndex = normalized.lastIndex(of: "#") {
            let pathPart = String(normalized[..<anchorIndex])
            let anchor = String(normalized[anchorIndex...])
            return compactPath(pathPart, maxLength: max(24, maxLength - anchor.count)) + anchor
        }
        return compactPath(normalized, maxLength: maxLength)
    }

    static func compactPath(_ path: String, maxLength: Int) -> String {
        guard path.count > maxLength else { return path }
        let headCount = max(12, (maxLength - 3) / 2)
        let tailCount = max(12, maxLength - 3 - headCount)
        let head = path.prefix(headCount)
        let tail = path.suffix(tailCount)
        return "\(head)...\(tail)"
    }

    func renderTable(headers: [String], rows: [[String]]) -> [String] {
        guard !headers.isEmpty else { return [] }
        var widths = headers.map(\.count)
        for row in rows {
            for index in 0..<min(row.count, widths.count) {
                widths[index] = max(widths[index], row[index].count)
            }
        }
        func pad(_ value: String, _ width: Int) -> String {
            if value.count >= width { return value }
            return value + String(repeating: " ", count: width - value.count)
        }
        let header = zip(headers, widths).map { pad($0.0, $0.1) }.joined(separator: " | ")
        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-|-")
        let body = rows.map { row in
            zip(row, widths).map { pad($0.0, $0.1) }.joined(separator: " | ")
        }
        return [header, separator] + body
    }

    static func resolveRepositoryFilePath(repositoryRoot: URL, path: String) -> String {
        if path.hasPrefix("/") {
            return STPath(path).url.path
        }
        return repositoryRoot.appendingPathComponent(path).standardizedFileURL.path
    }

    static func ensurePathWithinRepositoryRoot(_ resolvedPath: String, repositoryRoot: URL) throws {
        let rootPath = repositoryRoot.standardizedFileURL.path
        let candidatePath = STPath(resolvedPath).url.standardizedFileURL.path
        if candidatePath == rootPath { return }
        let rootWithSlash = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard candidatePath.hasPrefix(rootWithSlash) else {
            throw NolonCoreCLIError.invalidArguments(
                "Resolved --path is outside synced repository root: \(resolvedPath)"
            )
        }
    }

    static func resolveRepositoryInstallPath(
        kind: NolonRemoteCatalogKind,
        repositoryRoot: URL,
        path: String?,
        slug: String?,
        strictSelector: Bool,
        resources: NolonRepositoryResources
    ) throws -> RepositoryPathSelection {
        if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let resolved = resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: path)
            try ensurePathWithinRepositoryRoot(resolved, repositoryRoot: repositoryRoot)
            return RepositoryPathSelection(path: resolved, warnings: [])
        }
        guard let slug, !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --path or --slug")
        }

        switch kind {
        case .skill:
            let skillMatches = resources.skillsDirectories.filter { $0.skillNames.contains(slug) }
            if skillMatches.count > 1, strictSelector {
                let candidates = skillMatches.map { "\($0.path)/\(slug)" }
                throw NolonCoreCLIError.invalidArguments(
                    "Ambiguous --slug '\(slug)' matched multiple files: \(candidates.joined(separator: ", "))"
                )
            }
            if let dir = skillMatches.first {
                let warnings: [String]
                if skillMatches.count > 1 {
                    warnings = ["Ambiguous --slug '\(slug)' matched multiple files; selected first: \(dir.path)/\(slug)"]
                } else {
                    warnings = []
                }
                return RepositoryPathSelection(
                    path: resolveRepositoryFilePath(
                        repositoryRoot: repositoryRoot,
                        path: "\(dir.path)/\(slug)"
                    ),
                    warnings: warnings
                )
            }
            return RepositoryPathSelection(
                path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: "skills/\(slug)"),
                warnings: []
            )
        case .workflow:
            if let matched = try matchResourcePath(
                slug: slug,
                candidates: resources.workflows.map(\.path),
                strictSelector: strictSelector
            ) {
                return RepositoryPathSelection(
                    path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: matched.path),
                    warnings: matched.warnings
                )
            }
        case .mcp:
            if let matched = try matchResourcePath(
                slug: slug,
                candidates: resources.mcps.map(\.path),
                strictSelector: strictSelector
            ) {
                return RepositoryPathSelection(
                    path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: matched.path),
                    warnings: matched.warnings
                )
            }
        }

        throw NolonCoreCLIError.invalidArguments("Unable to resolve --slug '\(slug)' in synced repository")
    }

    static func matchResourcePath(
        slug: String,
        candidates: [String],
        strictSelector: Bool
    ) throws -> RepositoryPathSelection? {
        let normalized = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = candidates.first(where: { $0.lowercased() == normalized }) {
            return RepositoryPathSelection(path: exact, warnings: [])
        }
        let nameMatches = candidates.filter { STPath($0).url.lastPathComponent.lowercased() == normalized }
        if nameMatches.count > 1, strictSelector {
            throw NolonCoreCLIError.invalidArguments(
                "Ambiguous --slug '\(slug)' matched multiple files: \(nameMatches.joined(separator: ", "))"
            )
        }
        if let byName = nameMatches.first {
            let warnings: [String]
            if nameMatches.count > 1 {
                warnings = ["Ambiguous --slug '\(slug)' matched multiple files; selected first: \(byName)"]
            } else {
                warnings = []
            }
            return RepositoryPathSelection(path: byName, warnings: warnings)
        }
        let stemMatches = candidates.filter {
            let basename = STPath($0).url.lastPathComponent.lowercased()
            let stem = basename.split(separator: ".").dropLast().joined(separator: ".")
            return stem == normalized
        }
        if stemMatches.count > 1, strictSelector {
            throw NolonCoreCLIError.invalidArguments(
                "Ambiguous --slug '\(slug)' matched multiple files: \(stemMatches.joined(separator: ", "))"
            )
        }
        if let byStem = stemMatches.first {
            let warnings: [String]
            if stemMatches.count > 1 {
                warnings = ["Ambiguous --slug '\(slug)' matched multiple files; selected first: \(byStem)"]
            } else {
                warnings = []
            }
            return RepositoryPathSelection(path: byStem, warnings: warnings)
        }
        return nil
    }

}
