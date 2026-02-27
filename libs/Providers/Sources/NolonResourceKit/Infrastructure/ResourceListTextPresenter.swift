import Foundation

public enum ResourceListPresentationKind: String, Sendable, Equatable {
    case skill
    case workflow
    case mcp
}

public enum ResourceListPresentationState: String, Sendable, Equatable {
    case installed
    case orphaned
    case broken
}

public struct ResourceListPresentationItem: Sendable, Equatable {
    public let providerID: String
    public let resourceID: String
    public let state: ResourceListPresentationState
    public let path: String
    public let originDescription: String?

    public init(
        providerID: String,
        resourceID: String,
        state: ResourceListPresentationState,
        path: String,
        originDescription: String?
    ) {
        self.providerID = providerID
        self.resourceID = resourceID
        self.state = state
        self.path = path
        self.originDescription = originDescription
    }
}

public struct ResourceListPresentationSummary: Sendable, Equatable {
    public let providersScanned: Int
    public let providersMatched: Int
    public let totalCount: Int
    public let installedCount: Int
    public let orphanedCount: Int
    public let brokenCount: Int

    public init(
        providersScanned: Int,
        providersMatched: Int,
        totalCount: Int,
        installedCount: Int,
        orphanedCount: Int,
        brokenCount: Int
    ) {
        self.providersScanned = providersScanned
        self.providersMatched = providersMatched
        self.totalCount = totalCount
        self.installedCount = installedCount
        self.orphanedCount = orphanedCount
        self.brokenCount = brokenCount
    }
}

public struct ResourceListPresentationInput: Sendable, Equatable {
    public let kind: ResourceListPresentationKind
    public let providerFilter: String?
    public let stateFilter: ResourceListPresentationState?
    public let items: [ResourceListPresentationItem]
    public let summary: ResourceListPresentationSummary
    public let verbose: Bool
    public let showFixes: Bool

    public init(
        kind: ResourceListPresentationKind,
        providerFilter: String?,
        stateFilter: ResourceListPresentationState?,
        items: [ResourceListPresentationItem],
        summary: ResourceListPresentationSummary,
        verbose: Bool,
        showFixes: Bool
    ) {
        self.kind = kind
        self.providerFilter = providerFilter
        self.stateFilter = stateFilter
        self.items = items
        self.summary = summary
        self.verbose = verbose
        self.showFixes = showFixes
    }
}

public struct ResourceListTextPresenter: Sendable {
    public init() {}

    public func render(_ input: ResourceListPresentationInput) -> String {
        switch input.kind {
        case .skill:
            return renderSkillList(input)
        case .workflow, .mcp:
            return renderResourceList(input)
        }
    }

    private func renderSkillList(_ input: ResourceListPresentationInput) -> String {
        var lines: [String] = []
        let orphanedLabel = "失效链接"
        let metrics = ResourceListOverviewMetrics(
            installedCount: input.summary.installedCount,
            orphanedCount: input.summary.orphanedCount,
            brokenCount: input.summary.brokenCount,
            itemCount: input.summary.totalCount
        )
        let issueCount = ResourceListOverviewFormatter.issueCount(metrics)
        let compactHealthySummary = ResourceListOverviewFormatter.compactHealthySummary(
            showFixes: input.showFixes,
            verbose: input.verbose,
            hasProviderFilter: input.providerFilter != nil,
            hasStateFilter: input.stateFilter != nil,
            metrics: metrics
        )
        var filtersAppended = false
        func appendFiltersIfNeeded() {
            if filtersAppended { return }
            if let filter = input.providerFilter, !filter.isEmpty {
                lines.append("筛选-提供方: \(filter)")
            }
            if let stateFilter = input.stateFilter {
                lines.append("筛选-状态: \(localizedStateLabel(stateFilter))")
            }
            filtersAppended = true
        }

        lines.append("[结论]")
        if let summaryLine = ResourceListOverviewFormatter.summaryLine(showFixes: input.showFixes, metrics: metrics) {
            lines.append(summaryLine)
            lines.append("[详情]")
            appendFiltersIfNeeded()
        }
        if !compactHealthySummary {
            lines.append("providers_scanned: \(input.summary.providersScanned)")
            lines.append("providers_matched: \(input.summary.providersMatched)")
            lines.append("skills_total: \(input.summary.totalCount)")
        }
        if !input.showFixes || issueCount > 0 {
            lines.append(ResourceListOverviewFormatter.statusLine(metrics: metrics, orphanedLabel: orphanedLabel))
        }
        lines.append(contentsOf: ResourceListOverviewFormatter.conclusionLines(showFixes: input.showFixes, metrics: metrics, orphanedLabel: orphanedLabel))
        appendFiltersIfNeeded()

        if input.showFixes,
           issueCount == 0,
           !input.verbose,
           input.providerFilter == nil,
           input.stateFilter == nil {
            lines.append(ResourceListGuidancePolicy.installedHintLine(resourceDisplayLabel: "技能", command: "nolon skills list --state installed"))
            return lines.joined(separator: "\n")
        }

        let effectiveItems: [ResourceListPresentationItem]
        if input.verbose || input.stateFilter != nil {
            effectiveItems = input.items
        } else {
            effectiveItems = input.items.filter { $0.state != .installed }
        }

        let issueProviders = Array(Set(effectiveItems.filter { $0.state == .orphaned || $0.state == .broken }.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        if !issueProviders.isEmpty {
            lines.append("异常提供方(\(issueProviders.count)): \(issueProviders.joined(separator: ", "))")
        }

        let brokenIssueProviders = Array(Set(effectiveItems.filter { $0.state == .broken }.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        let orphanedIssueProviders = Array(Set(effectiveItems.filter { $0.state == .orphaned }.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if effectiveItems.isEmpty {
            lines.append(
                ResourceListGuidancePolicy.emptyResultLine(
                    resourceDisplayLabel: "技能",
                    providerFilter: input.providerFilter,
                    stateFilterLabel: input.stateFilter.map(localizedStateLabel),
                    orphanedLabel: orphanedLabel
                )
            )
            if input.stateFilter == nil {
                let installedCommand = "nolon skills list\(listFilterSuffix(provider: input.providerFilter, state: .installed))"
                lines.append(ResourceListGuidancePolicy.installedHintLine(resourceDisplayLabel: "技能", command: installedCommand))
            }
            if input.showFixes {
                lines.append("")
                lines.append("[下一步（可复制执行）]")
                lines.append(contentsOf: ResourceListGuidancePolicy.noFixesRetryLines(command: "nolon skills list --show-fixes"))
            }
            return lines.joined(separator: "\n")
        }

        let problematicItems = effectiveItems.filter { $0.state != .installed }
        let installedItems = effectiveItems.filter { $0.state == .installed }

        let itemLine: (ResourceListPresentationItem) -> String = { item in
            let stateLabel = localizedStateLabel(item.state)
            if input.verbose {
                var line = "- \(item.providerID)/\(item.resourceID)"
                if item.state != .installed {
                    line += " [\(stateLabel)]"
                }
                line += "\n  path: \(item.path)"
                if let origin = item.originDescription, !origin.isEmpty {
                    line += "\n  来源: \(origin)"
                }
                return line
            }
            if item.state == .installed {
                return "- \(item.providerID)/\(item.resourceID)"
            }
            return "- \(item.providerID)/\(item.resourceID) [\(stateLabel)]"
        }

        if !problematicItems.isEmpty {
            lines.append("")
            lines.append("[异常]")
            lines.append(contentsOf: problematicItems.map(itemLine))
        }
        if !installedItems.isEmpty {
            lines.append("")
            lines.append("[已安装]")
            lines.append(contentsOf: installedItems.map(itemLine))
        }
        if !input.verbose, !input.showFixes {
            lines.append("")
            lines.append(ResourceListGuidancePolicy.verboseHintLine(command: "nolon skills list --verbose"))
        }

        if !issueProviders.isEmpty, !input.showFixes {
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append("修复建议（可复制）:")
            let quickActions = ResourceListGuidancePolicy.skillsQuickActionItems(
                hasBroken: !brokenIssueProviders.isEmpty,
                hasOrphaned: !orphanedIssueProviders.isEmpty
            )
            lines.append(contentsOf: quickActions.enumerated().map { index, action in
                "\(index + 1)) \(action)"
            })
        }

        let orphanedItems = effectiveItems.filter { $0.state == .orphaned }
        let brokenItems = effectiveItems.filter { $0.state == .broken }
        if input.showFixes, (!orphanedItems.isEmpty || !brokenItems.isEmpty) {
            lines.append("")
            lines.append("[下一步（按顺序执行）]")
            if !orphanedItems.isEmpty {
                lines.append("")
                lines.append("1. 清理\(orphanedLabel)（\(orphanedItems.count)项）")
                let groupedOrphaned = Dictionary(grouping: orphanedItems, by: \.providerID)
                for providerID in groupedOrphaned.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                    guard let items = groupedOrphaned[providerID] else { continue }
                    lines.append("provider: \(providerID) (\(items.count))")
                    for item in items.sorted(by: { $0.resourceID.localizedCaseInsensitiveCompare($1.resourceID) == .orderedAscending }) {
                        let command = ResourceRepairPlanner.command(
                            kind: .skill,
                            item: RepairItem(providerID: item.providerID, resourceID: item.resourceID, state: item.state == .broken ? .broken : .orphaned)
                        )
                        lines.append("- `\(command)`")
                    }
                }
            }
            if !brokenItems.isEmpty {
                lines.append("")
                lines.append("2. 修复损坏（\(brokenItems.count)项：先 remove 再 add）")
                let groupedBroken = Dictionary(grouping: brokenItems, by: \.providerID)
                for providerID in groupedBroken.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                    guard let items = groupedBroken[providerID] else { continue }
                    lines.append("provider: \(providerID) (\(items.count))")
                    for item in items.sorted(by: { $0.resourceID.localizedCaseInsensitiveCompare($1.resourceID) == .orderedAscending }) {
                        let command = ResourceRepairPlanner.command(
                            kind: .skill,
                            item: RepairItem(providerID: item.providerID, resourceID: item.resourceID, state: item.state == .broken ? .broken : .orphaned)
                        )
                        lines.append("- `\(command)`")
                    }
                }
            }
            lines.append("")
            lines.append("3. 复检")
            lines.append("`nolon skills list --show-fixes`")
        } else if input.showFixes, input.providerFilter != nil || input.stateFilter != nil || issueCount > 0 {
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append(contentsOf: ResourceListGuidancePolicy.noFixesRetryLines(command: "nolon skills list --show-fixes"))
        }

        return lines.joined(separator: "\n")
    }

    private func renderResourceList(_ input: ResourceListPresentationInput) -> String {
        var lines: [String] = []
        let orphanedLabel = "失效链接"
        let metrics = ResourceListOverviewMetrics(
            installedCount: input.summary.installedCount,
            orphanedCount: input.summary.orphanedCount,
            brokenCount: input.summary.brokenCount,
            itemCount: input.summary.totalCount
        )
        let issueCount = ResourceListOverviewFormatter.issueCount(metrics)
        let compactHealthySummary = ResourceListOverviewFormatter.compactHealthySummary(
            showFixes: input.showFixes,
            verbose: input.verbose,
            hasProviderFilter: input.providerFilter != nil,
            hasStateFilter: input.stateFilter != nil,
            metrics: metrics
        )

        var filtersAppended = false
        func appendFiltersIfNeeded() {
            if filtersAppended { return }
            if let filter = input.providerFilter, !filter.isEmpty {
                lines.append("筛选-提供方: \(filter)")
            }
            if let stateFilter = input.stateFilter {
                lines.append("筛选-状态: \(localizedStateLabel(stateFilter))")
            }
            filtersAppended = true
        }

        lines.append("[结论]")
        if let summaryLine = ResourceListOverviewFormatter.summaryLine(showFixes: input.showFixes, metrics: metrics) {
            lines.append(summaryLine)
            lines.append("[详情]")
            appendFiltersIfNeeded()
        }
        if !compactHealthySummary {
            lines.append("providers_scanned: \(input.summary.providersScanned)")
            lines.append("providers_matched: \(input.summary.providersMatched)")
            lines.append("\(totalKey(for: input.kind)): \(input.summary.totalCount)")
        }
        if !input.showFixes || issueCount > 0 {
            lines.append(ResourceListOverviewFormatter.statusLine(metrics: metrics, orphanedLabel: orphanedLabel))
        }
        lines.append(contentsOf: ResourceListOverviewFormatter.conclusionLines(showFixes: input.showFixes, metrics: metrics, orphanedLabel: orphanedLabel))
        appendFiltersIfNeeded()

        if input.showFixes,
           issueCount == 0,
           !input.verbose,
           input.providerFilter == nil,
           input.stateFilter == nil {
            lines.append(
                ResourceListGuidancePolicy.installedHintLine(
                    resourceDisplayLabel: displayResourceLabel(localizedResourceKindLabel(input.kind)),
                    command: "nolon \(input.kind.rawValue) list --state installed"
                )
            )
            return lines.joined(separator: "\n")
        }

        let items: [ResourceListPresentationItem]
        if input.verbose || input.stateFilter != nil {
            items = input.items
        } else {
            items = input.items.filter { $0.state != .installed }
        }

        if items.isEmpty {
            lines.append(
                ResourceListGuidancePolicy.emptyResultLine(
                    resourceDisplayLabel: displayResourceLabel(localizedResourceKindLabel(input.kind)),
                    providerFilter: input.providerFilter,
                    stateFilterLabel: input.stateFilter.map(localizedStateLabel),
                    orphanedLabel: orphanedLabel
                )
            )
            if input.stateFilter == nil {
                lines.append(
                    ResourceListGuidancePolicy.installedHintLine(
                        resourceDisplayLabel: displayResourceLabel(localizedResourceKindLabel(input.kind)),
                        command: "nolon \(input.kind.rawValue) list\(listFilterSuffix(provider: input.providerFilter, state: .installed))"
                    )
                )
            }
            if input.showFixes {
                lines.append("")
                lines.append("可选复检:")
                lines.append("- 直接运行: `nolon \(input.kind.rawValue) list --show-fixes`")
                lines.append("- 源码模式: `swift run --package-path libs/Providers nolon \(input.kind.rawValue) list --show-fixes`")
            }
            return lines.joined(separator: "\n")
        }

        let problematicItems = items.filter { $0.state != .installed }
        let installedItems = items.filter { $0.state == .installed }
        let providers = Array(Set(problematicItems.map(\.providerID))).sorted()
        if !providers.isEmpty {
            lines.append("异常提供方(\(providers.count)): \(providers.joined(separator: ", "))")
        }

        if !problematicItems.isEmpty {
            lines.append("")
            lines.append("[异常]")
            lines.append(contentsOf: problematicItems.map { item in
                let stateLabel = item.state == .orphaned ? orphanedLabel : localizedStateLabel(item.state)
                if input.verbose {
                    var line = "- \(item.providerID)/\(item.resourceID) [\(stateLabel)]\n  path: \(item.path)"
                    if let origin = item.originDescription, !origin.isEmpty {
                        line += "\n  来源: \(origin)"
                    }
                    return line
                }
                return "- \(item.providerID)/\(item.resourceID) [\(stateLabel)]"
            })
        }

        if !installedItems.isEmpty {
            lines.append("")
            lines.append("[已安装]")
            lines.append(contentsOf: installedItems.map { item in
                if input.verbose {
                    var line = "- \(item.providerID)/\(item.resourceID)"
                    line += "\n  path: \(item.path)"
                    if let origin = item.originDescription, !origin.isEmpty {
                        line += "\n  来源: \(origin)"
                    }
                    return line
                }
                return "- \(item.providerID)/\(item.resourceID)"
            })
        }

        if !input.verbose, !input.showFixes {
            lines.append("")
            lines.append(ResourceListGuidancePolicy.verboseHintLine(command: "nolon \(input.kind.rawValue) list --verbose"))
        }

        let fixCommands = buildFixCommands(kind: input.kind, items: problematicItems)
        if !fixCommands.simple.isEmpty, !input.showFixes {
            let filterSuffix = listFilterSuffix(provider: input.providerFilter, state: input.stateFilter)
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append("修复建议（可复制）:")
            let quickActions = ResourceListGuidancePolicy.resourceQuickActionItems(
                singleFixCommand: fixCommands.detailed.count == 1 ? fixCommands.simple : nil,
                showFixesCommand: "nolon \(input.kind.rawValue) list\(filterSuffix) --show-fixes",
                verboseShowFixesCommand: "nolon \(input.kind.rawValue) list\(filterSuffix) --verbose --show-fixes"
            )
            lines.append(contentsOf: quickActions.enumerated().map { index, action in
                "\(index + 1)) \(action)"
            })
        }

        if input.showFixes, !fixCommands.detailed.isEmpty {
            lines.append("")
            lines.append("[下一步（按顺序执行）]")
            lines.append("修复计划:")
            lines.append("1. 清理异常项（\(fixCommands.detailed.count)项）")
            let groupedByProvider = Dictionary(grouping: problematicItems, by: \.providerID)
            for providerID in groupedByProvider.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                guard let providerItems = groupedByProvider[providerID] else { continue }
                lines.append("provider: \(providerID) (\(providerItems.count))")
                for item in providerItems.sorted(by: { $0.resourceID.localizedCaseInsensitiveCompare($1.resourceID) == .orderedAscending }) {
                    let command = ResourceRepairPlanner.command(
                        kind: toRepairResourceKind(input.kind),
                        item: RepairItem(providerID: item.providerID, resourceID: item.resourceID, state: item.state == .broken ? .broken : .orphaned)
                    )
                    lines.append("- `\(command)`")
                }
            }
            lines.append("")
            lines.append("2. 复检")
            lines.append("`nolon \(input.kind.rawValue) list --show-fixes`")
        } else if input.showFixes, input.providerFilter != nil || input.stateFilter != nil || issueCount > 0 {
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append(contentsOf: ResourceListGuidancePolicy.noFixesRetryLines(command: "nolon \(input.kind.rawValue) list --show-fixes"))
        }

        return lines.joined(separator: "\n")
    }

    private func buildFixCommands(
        kind: ResourceListPresentationKind,
        items: [ResourceListPresentationItem]
    ) -> (simple: String, detailed: [String]) {
        let planItems = items.filter { $0.state != .installed }.map {
            RepairItem(providerID: $0.providerID, resourceID: $0.resourceID, state: $0.state == .broken ? .broken : .orphaned)
        }
        let plan = ResourceRepairPlanner.plan(kind: toRepairResourceKind(kind), items: planItems)
        let detailed = plan.steps.flatMap(\.commands)
        return (simple: detailed.first ?? "", detailed: detailed)
    }

    private func toRepairResourceKind(_ kind: ResourceListPresentationKind) -> RepairResourceKind {
        switch kind {
        case .skill:
            return .skill
        case .workflow:
            return .workflow
        case .mcp:
            return .mcp
        }
    }

    private func totalKey(for kind: ResourceListPresentationKind) -> String {
        switch kind {
        case .workflow: return "workflow_total"
        case .mcp: return "mcp_total"
        case .skill: return "skills_total"
        }
    }

    private func listFilterSuffix(provider: String?, state: ResourceListPresentationState?) -> String {
        var parts: [String] = []
        if let provider, !provider.isEmpty {
            parts.append("--provider \(provider)")
        }
        if let state {
            parts.append("--state \(state.rawValue)")
        }
        guard !parts.isEmpty else { return "" }
        return " " + parts.joined(separator: " ")
    }

    private func localizedStateLabel(_ state: ResourceListPresentationState) -> String {
        switch state {
        case .installed: return "已安装"
        case .orphaned: return "失效链接"
        case .broken: return "损坏"
        }
    }

    private func localizedResourceKindLabel(_ kind: ResourceListPresentationKind) -> String {
        switch kind {
        case .workflow: return "工作流资源"
        case .mcp: return "MCP 资源"
        case .skill: return "技能"
        }
    }

    private func displayResourceLabel(_ label: String) -> String {
        guard let first = label.unicodeScalars.first else { return label }
        return first.isASCII ? " \(label)" : label
    }
}
