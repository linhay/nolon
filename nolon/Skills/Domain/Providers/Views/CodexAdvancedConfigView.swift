import AppKit
import Observation
import ProviderCatalog
import SwiftUI
import UniformTypeIdentifiers
import STFilePath
import CodexProvider
import NolonResourceKit
import NolonUI
import NolonUIFoundation

private enum CodexAdvancedDocs {
    static let configBasics = "https://developers.openai.com/codex/config-basic"
    static let configAdvanced = "https://developers.openai.com/codex/config-advanced"
    static let configReference = "https://developers.openai.com/codex/config-reference"
    static let sandboxing = "https://developers.openai.com/codex/concepts/sandboxing"
    static let approvals = "https://developers.openai.com/codex/agent-approvals-security"
    static let subagents = "https://developers.openai.com/codex/concepts/subagents"
    static let models = "https://developers.openai.com/codex/models"
    static let compaction = "https://developers.openai.com/codex/compaction"
}

enum CodexLinkFolder: String, CaseIterable, Identifiable, Hashable {
    case prompts
    case rules
    case skills

    var id: String { rawValue }
}

struct CodexLinkState: Sendable {
    let folder: CodexLinkFolder
    let sourceURL: URL
    let targetURL: URL
    let isLinked: Bool
    let hasVisibleEntries: Bool
}

struct CodexLinkConflict: Identifiable {
    let folder: CodexLinkFolder
    let targetURL: URL

    var id: String { folder.rawValue }
}

struct CodexConfigDocLink: Identifiable, Sendable {
    let id: String
    let title: String
    let url: String
}

struct CodexAdvancedStructuredDraft: Sendable {
    let approvalPolicy: String?
    let sandboxMode: String?
    let webSearch: String?
    let modelProvider: String?
    let profile: String?
    let personality: String?
    let hideAgentReasoning: Bool?
    let modelAutoCompactTokenLimit: Int?
    let compactPrompt: String?
    let experimentalCompactPromptFile: String?
    let reasoningSummary: String?
    let verbosity: String?
    let historyPersistence: String?
    let historyMaxBytes: Int?
    let featureValues: [String: Bool]
    let agentsMaxThreads: Int?
    let agentsMaxDepth: Int?
    let roleDrafts: [CodexAgentRoleDraft]
    let preservedTopLevelRawValues: [String: String]
    let preservedHistoryRawValues: [String: String]
    let preservedRoleRawValues: [String: [String: String]]
}

struct CodexStructuredConfigPatchService: Sendable {
    private struct SectionBlock: Equatable {
        let name: String
        let header: String
        var body: [String]

        var renderedLines: [String] { [header] + body }
    }

    private struct Document: Equatable {
        var preamble: [String]
        var sections: [SectionBlock]
        let hasTrailingNewline: Bool
    }

    private let controlledTopLevelKeys: [String] = [
        "approval_policy",
        "sandbox_mode",
        "web_search",
        "model_provider",
        "profile",
        "personality",
        "hide_agent_reasoning",
        "model_auto_compact_token_limit",
        "compact_prompt",
        "experimental_compact_prompt_file",
        "model_reasoning_summary",
        "model_verbosity"
    ]

    private let controlledHistoryKeys: [String] = [
        "persistence",
        "max_bytes"
    ]

    private let controlledRoleKeys: [String] = [
        "description",
        "config_file",
        "model",
        "model_reasoning_effort",
        "model_reasoning_summary",
        "model_verbosity",
        "approval_policy",
        "sandbox_mode",
        "personality",
        "web_search"
    ]

    func patch(original: String, draft: CodexAdvancedStructuredDraft) throws -> String {
        var document = parseDocument(original.replacingOccurrences(of: "\r\n", with: "\n"))
        patchTopLevel(in: &document, draft: draft)
        patchHistory(in: &document, draft: draft)
        patchFeatures(in: &document, draft: draft)
        patchAgents(in: &document, draft: draft)
        return renderDocument(document)
    }

    func extractDraft(from original: String) -> CodexAdvancedStructuredDraft {
        let document = parseDocument(original.replacingOccurrences(of: "\r\n", with: "\n"))
        let topLevelAssignments = Dictionary(uniqueKeysWithValues: document.preamble.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line), let value = parseRawAssignmentValue(from: line) else { return nil }
            return (key, value)
        })
        let preservedTopLevelRawValues = preservedRawValues(
            keys: controlledTopLevelKeys,
            assignments: topLevelAssignments,
            typedKeys: stringKeys.union(boolKeys).union(intKeys)
        )

        let featureValues = document.sections
            .first(where: { $0.name == "features" })
            .map(parseBooleanAssignments(in:)) ?? [:]

        let historySection = document.sections.first(where: { $0.name == "history" })
        let historyAssignments = historySection.map(parseRawAssignments(in:)) ?? [:]
        let preservedHistoryRawValues = preservedRawValues(
            keys: controlledHistoryKeys,
            assignments: historyAssignments,
            typedKeys: historyStringKeys.union(historyIntKeys)
        )

        let agentsSection = document.sections.first(where: { $0.name == "agents" })
        let roles = document.sections
            .filter { $0.name.hasPrefix("agents.") }
            .map { section -> CodexAgentRoleDraft in
                let roleName = String(section.name.dropFirst("agents.".count))
                let values = parseAssignments(in: section)
                return CodexAgentRoleDraft(
                    name: roleName,
                    description: values["description"] ?? "",
                    configFile: values["config_file"] ?? "",
                    model: values["model"] ?? "",
                    modelReasoningEffort: values["model_reasoning_effort"] ?? "",
                    modelReasoningSummary: values["model_reasoning_summary"] ?? "",
                    modelVerbosity: values["model_verbosity"] ?? "",
                    sandboxMode: values["sandbox_mode"] ?? "",
                    approvalPolicy: values["approval_policy"] ?? "",
                    personality: values["personality"] ?? "",
                    webSearch: values["web_search"] ?? ""
                )
            }
        let preservedRoleRawValues = Dictionary(
            uniqueKeysWithValues: document.sections
                .filter { $0.name.hasPrefix("agents.") }
                .compactMap { section -> (String, [String: String])? in
                    let roleName = String(section.name.dropFirst("agents.".count))
                    let rawAssignments = parseRawAssignments(in: section)
                    let preserved = preservedRawValues(
                        keys: controlledRoleKeys,
                        assignments: rawAssignments,
                        typedKeys: roleStringKeys
                    )
                    guard !preserved.isEmpty else { return nil }
                    return (roleName, preserved)
                }
        )

        return CodexAdvancedStructuredDraft(
            approvalPolicy: parseStringValue(for: "approval_policy", in: topLevelAssignments),
            sandboxMode: parseStringValue(for: "sandbox_mode", in: topLevelAssignments),
            webSearch: parseStringValue(for: "web_search", in: topLevelAssignments),
            modelProvider: parseStringValue(for: "model_provider", in: topLevelAssignments),
            profile: parseStringValue(for: "profile", in: topLevelAssignments),
            personality: parseStringValue(for: "personality", in: topLevelAssignments),
            hideAgentReasoning: parseBoolValue(for: "hide_agent_reasoning", in: topLevelAssignments),
            modelAutoCompactTokenLimit: parseIntValue(for: "model_auto_compact_token_limit", in: topLevelAssignments),
            compactPrompt: parseStringValue(for: "compact_prompt", in: topLevelAssignments),
            experimentalCompactPromptFile: parseStringValue(for: "experimental_compact_prompt_file", in: topLevelAssignments),
            reasoningSummary: parseStringValue(for: "model_reasoning_summary", in: topLevelAssignments),
            verbosity: parseStringValue(for: "model_verbosity", in: topLevelAssignments),
            historyPersistence: parseStringValue(for: "persistence", in: historyAssignments),
            historyMaxBytes: parseIntValue(for: "max_bytes", in: historyAssignments),
            featureValues: featureValues,
            agentsMaxThreads: agentsSection.flatMap { parseIntegerValue(for: "max_threads", in: $0) },
            agentsMaxDepth: agentsSection.flatMap { parseIntegerValue(for: "max_depth", in: $0) },
            roleDrafts: roles,
            preservedTopLevelRawValues: preservedTopLevelRawValues,
            preservedHistoryRawValues: preservedHistoryRawValues,
            preservedRoleRawValues: preservedRoleRawValues
        )
    }

    private func parseDocument(_ text: String) -> Document {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var preamble: [String] = []
        var sections: [SectionBlock] = []
        var currentSectionName: String?
        var currentSectionHeader: String?
        var currentBody: [String] = []

        func flushCurrentSection() {
            guard let currentSectionName, let currentSectionHeader else { return }
            sections.append(
                SectionBlock(
                    name: currentSectionName,
                    header: currentSectionHeader,
                    body: currentBody
                )
            )
        }

        for line in lines {
            if let sectionName = parseSectionName(from: line) {
                flushCurrentSection()
                currentSectionName = sectionName
                currentSectionHeader = line
                currentBody = []
                continue
            }

            if currentSectionName == nil {
                preamble.append(line)
            } else {
                currentBody.append(line)
            }
        }
        flushCurrentSection()
        return Document(
            preamble: preamble,
            sections: sections,
            hasTrailingNewline: text.hasSuffix("\n")
        )
    }

    private func renderDocument(_ document: Document) -> String {
        var lines = document.preamble
        for section in document.sections {
            lines.append(contentsOf: section.renderedLines)
        }
        var output = lines.joined(separator: "\n")
        if document.hasTrailingNewline || !output.isEmpty {
            output += "\n"
        }
        return output
    }

    private func patchTopLevel(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let generated = compactGeneratedLines([
            generatedStringLine(key: "approval_policy", value: draft.approvalPolicy, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "sandbox_mode", value: draft.sandboxMode, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "web_search", value: draft.webSearch, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "model_provider", value: draft.modelProvider, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "profile", value: draft.profile, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "personality", value: draft.personality, preserved: draft.preservedTopLevelRawValues),
            generatedBoolLine(key: "hide_agent_reasoning", value: draft.hideAgentReasoning, preserved: draft.preservedTopLevelRawValues),
            generatedIntLine(key: "model_auto_compact_token_limit", value: draft.modelAutoCompactTokenLimit, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "compact_prompt", value: draft.compactPrompt, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "experimental_compact_prompt_file", value: draft.experimentalCompactPromptFile, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "model_reasoning_summary", value: draft.reasoningSummary, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "model_verbosity", value: draft.verbosity, preserved: draft.preservedTopLevelRawValues)
        ])

        document.preamble = appendGeneratedLines(
            generated,
            to: filteredLines(in: document.preamble, removingKeys: Set(controlledTopLevelKeys))
        )
    }

    private func patchHistory(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let generated = compactGeneratedLines([
            generatedStringLine(key: "persistence", value: draft.historyPersistence, preserved: draft.preservedHistoryRawValues),
            generatedIntLine(key: "max_bytes", value: draft.historyMaxBytes, preserved: draft.preservedHistoryRawValues)
        ])

        let sectionIndex = document.sections.firstIndex(where: { $0.name == "history" })
        let existingBody = sectionIndex.map { document.sections[$0].body } ?? []
        let filteredBody = appendGeneratedLines(
            generated,
            to: filteredLines(in: existingBody, removingKeys: Set(controlledHistoryKeys))
        )

        if !sectionHasMeaningfulContent(filteredBody) {
            if let sectionIndex {
                document.sections.remove(at: sectionIndex)
            }
            return
        }

        let section = SectionBlock(name: "history", header: "[history]", body: filteredBody)
        if let sectionIndex {
            document.sections[sectionIndex] = section
        } else {
            document.sections.append(section)
        }
    }

    private func patchFeatures(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let controlledKeys = Set(draft.featureValues.keys)
        let generated = draft.featureValues
            .sorted { $0.key < $1.key }
            .map { boolAssignmentLine(key: $0.key, value: $0.value) }

        let sectionIndex = document.sections.firstIndex(where: { $0.name == "features" })
        let existingBody = sectionIndex.map { document.sections[$0].body } ?? []
        let filteredBody = patchBody(
            existingBody,
            removingKeys: controlledKeys,
            generatedLines: generated
        )

        if !sectionHasMeaningfulContent(filteredBody) {
            if let sectionIndex {
                document.sections.remove(at: sectionIndex)
            }
            return
        }

        let section = SectionBlock(name: "features", header: "[features]", body: filteredBody)
        if let sectionIndex {
            document.sections[sectionIndex] = section
        } else {
            document.sections.append(section)
        }
    }

    private func patchAgents(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let agentsIndices = document.sections.indices.filter {
            let name = document.sections[$0].name
            return name == "agents" || name.hasPrefix("agents.")
        }
        let firstAgentsIndex = agentsIndices.first
        let existingSections = agentsIndices.map { document.sections[$0] }
        let existingParentSection = existingSections.first(where: { $0.name == "agents" })
        let existingRoleSections = existingSections.filter { $0.name.hasPrefix("agents.") }

        let parentGenerated = [
            intAssignmentLine(key: "max_threads", value: draft.agentsMaxThreads),
            intAssignmentLine(key: "max_depth", value: draft.agentsMaxDepth)
        ].compactMap { $0 }
        let patchedParentBody = patchBody(
            existingParentSection?.body ?? [],
            removingKeys: ["max_threads", "max_depth"],
            generatedLines: parentGenerated
        )

        var patchedCluster: [SectionBlock] = []
        let roleDraftsByName = Dictionary(uniqueKeysWithValues: draft.roleDrafts.compactMap { role -> (String, CodexAgentRoleDraft)? in
            let name = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, role)
        })

        if sectionHasMeaningfulContent(patchedParentBody) || !roleDraftsByName.isEmpty {
            patchedCluster.append(
                SectionBlock(
                    name: "agents",
                    header: "[agents]",
                    body: patchedParentBody
                )
            )
        }

        var existingRoleNames = Set<String>()
        for section in existingRoleSections {
            let roleName = String(section.name.dropFirst("agents.".count))
            guard let roleDraft = roleDraftsByName[roleName] else { continue }
            existingRoleNames.insert(roleName)
            patchedCluster.append(
                SectionBlock(
                    name: section.name,
                    header: section.header,
                    body: patchRoleBody(section.body, role: roleDraft)
                )
            )
        }

        for role in draft.roleDrafts {
            let roleName = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !roleName.isEmpty, !existingRoleNames.contains(roleName) else { continue }
            patchedCluster.append(
                SectionBlock(
                    name: "agents.\(roleName)",
                    header: "[agents.\(roleName)]",
                    body: patchRoleBody([], role: role)
                )
            )
        }

        for index in agentsIndices.sorted(by: >) {
            document.sections.remove(at: index)
        }

        guard !patchedCluster.isEmpty else { return }
        let insertionIndex = firstAgentsIndex ?? document.sections.count
        document.sections.insert(contentsOf: patchedCluster, at: insertionIndex)
    }

    private func patchRoleBody(_ body: [String], role: CodexAgentRoleDraft) -> [String] {
        let preserved = role.preservedRawValues
        let generated = compactGeneratedLines([
            generatedStringLine(key: "description", value: normalized(role.description), preserved: preserved),
            generatedStringLine(key: "config_file", value: normalized(role.configFile), preserved: preserved),
            generatedStringLine(key: "model", value: normalized(role.model), preserved: preserved),
            generatedStringLine(key: "model_reasoning_effort", value: normalized(role.modelReasoningEffort), preserved: preserved),
            generatedStringLine(key: "model_reasoning_summary", value: normalized(role.modelReasoningSummary), preserved: preserved),
            generatedStringLine(key: "model_verbosity", value: normalized(role.modelVerbosity), preserved: preserved),
            generatedStringLine(key: "approval_policy", value: normalized(role.approvalPolicy), preserved: preserved),
            generatedStringLine(key: "sandbox_mode", value: normalized(role.sandboxMode), preserved: preserved),
            generatedStringLine(key: "personality", value: normalized(role.personality), preserved: preserved),
            generatedStringLine(key: "web_search", value: normalized(role.webSearch), preserved: preserved)
        ])

        return appendGeneratedLines(
            generated,
            to: filteredLines(in: body, removingKeys: Set(controlledRoleKeys))
        )
    }

    private func patchBody(
        _ body: [String],
        removingKeys: Set<String>,
        generatedLines: [String]
    ) -> [String] {
        appendGeneratedLines(generatedLines, to: filteredLines(in: body, removingKeys: removingKeys))
    }

    private func filteredLines(in lines: [String], removingKeys: Set<String>) -> [String] {
        var filtered: [String] = []
        for line in lines {
            guard let key = parseAssignmentKey(from: line), removingKeys.contains(key) else {
                filtered.append(line)
                continue
            }
        }
        return filtered
    }

    private func appendGeneratedLines(_ generatedLines: [String], to existingLines: [String]) -> [String] {
        guard !generatedLines.isEmpty else { return existingLines }
        var lines = existingLines
        while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeLast()
        }
        if let last = lines.last, !last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
        }
        lines.append(contentsOf: generatedLines)
        return lines
    }

    private func parseSectionName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), !trimmed.hasPrefix("[[") else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    private func parseAssignmentKey(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            !trimmed.hasPrefix("#"),
            let equalIndex = trimmed.firstIndex(of: "=")
        else {
            return nil
        }
        let key = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("[") else { return nil }
        return String(key)
    }

    private var stringKeys: Set<String> {
        [
            "approval_policy",
            "sandbox_mode",
            "web_search",
            "model_provider",
            "profile",
            "personality",
            "compact_prompt",
            "experimental_compact_prompt_file",
            "model_reasoning_summary",
            "model_verbosity"
        ]
    }

    private var boolKeys: Set<String> {
        ["hide_agent_reasoning"]
    }

    private var intKeys: Set<String> {
        ["model_auto_compact_token_limit"]
    }

    private var historyStringKeys: Set<String> {
        ["persistence"]
    }

    private var historyIntKeys: Set<String> {
        ["max_bytes"]
    }

    private var roleStringKeys: Set<String> {
        Set(controlledRoleKeys)
    }

    private func parseRawAssignments(in section: SectionBlock) -> [String: String] {
        Dictionary(uniqueKeysWithValues: section.body.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line), let value = parseRawAssignmentValue(from: line) else { return nil }
            return (key, value)
        })
    }

    private func parseAssignments(in section: SectionBlock) -> [String: String] {
        Dictionary(uniqueKeysWithValues: section.body.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line), let value = parseStringValue(from: line) else { return nil }
            return (key, value)
        })
    }

    private func parseBooleanAssignments(in section: SectionBlock) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: section.body.compactMap { line -> (String, Bool)? in
            guard let key = parseAssignmentKey(from: line), let value = parseBooleanValue(from: line) else { return nil }
            return (key, value)
        })
    }

    private func parseIntegerValue(for key: String, in section: SectionBlock) -> Int? {
        for line in section.body {
            guard parseAssignmentKey(from: line) == key else { continue }
            guard let equalIndex = line.firstIndex(of: "=") else { continue }
            let rawValue = line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(rawValue)
        }
        return nil
    }

    private func parseRawAssignmentValue(from line: String) -> String? {
        guard let equalIndex = line.firstIndex(of: "=") else { return nil }
        return line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseStringValue(for key: String, in assignments: [String: String]) -> String? {
        guard let raw = assignments[key] else { return nil }
        return parseStringValue(fromRawValue: raw)
    }

    private func parseBoolValue(for key: String, in assignments: [String: String]) -> Bool? {
        guard let raw = assignments[key] else { return nil }
        return parseBoolValue(fromRawValue: raw)
    }

    private func parseIntValue(for key: String, in assignments: [String: String]) -> Int? {
        guard let raw = assignments[key] else { return nil }
        return Int(raw)
    }

    private func parseStringValue(from line: String) -> String? {
        guard let rawValue = parseRawAssignmentValue(from: line) else { return nil }
        return parseStringValue(fromRawValue: rawValue)
    }

    private func parseStringValue(fromRawValue rawValue: String) -> String? {
        guard rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 else { return nil }
        let inner = rawValue.dropFirst().dropLast()
        return inner
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private func parseBooleanValue(from line: String) -> Bool? {
        guard let rawValue = parseRawAssignmentValue(from: line) else { return nil }
        return parseBoolValue(fromRawValue: rawValue)
    }

    private func parseBoolValue(fromRawValue rawValue: String) -> Bool? {
        switch rawValue {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    private func sectionHasMeaningfulContent(_ body: [String]) -> Bool {
        body.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func preservedRawValues(
        keys: [String],
        assignments: [String: String],
        typedKeys: Set<String>
    ) -> [String: String] {
        Dictionary(uniqueKeysWithValues: keys.compactMap { key -> (String, String)? in
            guard let rawValue = assignments[key], typedKeys.contains(key) else { return nil }
            if stringKeys.contains(key), parseStringValue(fromRawValue: rawValue) != nil { return nil }
            if boolKeys.contains(key), parseBoolValue(fromRawValue: rawValue) != nil { return nil }
            if intKeys.contains(key), Int(rawValue) != nil { return nil }
            if historyStringKeys.contains(key), parseStringValue(fromRawValue: rawValue) != nil { return nil }
            if historyIntKeys.contains(key), Int(rawValue) != nil { return nil }
            if roleStringKeys.contains(key), parseStringValue(fromRawValue: rawValue) != nil { return nil }
            return (key, rawValue)
        })
    }

    private func stringAssignmentLine(key: String, value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(key) = \"\(escaped)\""
    }

    private func boolAssignmentLine(key: String, value: Bool) -> String {
        "\(key) = \(value ? "true" : "false")"
    }

    private func intAssignmentLine(key: String, value: Int?) -> String? {
        guard let value else { return nil }
        return "\(key) = \(value)"
    }

    private func compactGeneratedLines(_ lines: [String?]) -> [String] {
        lines.compactMap { $0 }
    }

    private func generatedStringLine(key: String, value: String?, preserved: [String: String]) -> String? {
        if let line = stringAssignmentLine(key: key, value: value) {
            return line
        }
        guard let raw = preserved[key] else { return nil }
        return "\(key) = \(raw)"
    }

    private func generatedBoolLine(key: String, value: Bool?, preserved: [String: String]) -> String? {
        if let value {
            return boolAssignmentLine(key: key, value: value)
        }
        guard let raw = preserved[key] else { return nil }
        return "\(key) = \(raw)"
    }

    private func generatedIntLine(key: String, value: Int?, preserved: [String: String]) -> String? {
        if let value {
            return intAssignmentLine(key: key, value: value)
        }
        guard let raw = preserved[key] else { return nil }
        return "\(key) = \(raw)"
    }
}

struct CodexFeatureDefinition: Identifiable, Sendable {
    let key: String
    let maturity: String
    let description: String
    let source: String

    var id: String { key }
}

private enum CodexFeatureSourceTag: String, CaseIterable {
    case coreFeatures
    case cliFeaturesList
    case appServer
    case codexDocs
    case nolonCompatibility
    case configUnknown

    var localizedTitle: String {
        switch self {
        case .coreFeatures:
            return NSLocalizedString("codex.features.source.tag.core_features", value: "Core Features", comment: "Core features source tag")
        case .cliFeaturesList:
            return NSLocalizedString("codex.features.source.tag.cli_features_list", value: "CLI Features List", comment: "CLI features list source tag")
        case .appServer:
            return NSLocalizedString("codex.features.source.tag.app_server", value: "App Server", comment: "App server source tag")
        case .codexDocs:
            return NSLocalizedString("codex.features.source.tag.codex_docs", value: "Codex Docs", comment: "Codex docs source tag")
        case .nolonCompatibility:
            return NSLocalizedString("codex.features.source.tag.nolon_compatibility", value: "Nolon Compatibility", comment: "Nolon compatibility source tag")
        case .configUnknown:
            return NSLocalizedString("codex.features.source.tag.config_unknown", value: "Config Unknown Key", comment: "Config unknown source tag")
        }
    }
}

struct CodexAgentRoleDraft: Identifiable, Equatable, Sendable {
    let id = UUID()
    var name: String
    var description: String
    var configFile: String
    var model: String
    var modelReasoningEffort: String
    var modelReasoningSummary: String
    var modelVerbosity: String
    var sandboxMode: String
    var approvalPolicy: String
    var personality: String
    var webSearch: String
    var preservedRawValues: [String: String] = [:]
}

enum CodexBuiltinAgentRole: String, CaseIterable, Identifiable {
    case `default`
    case worker
    case explorer
    case monitor

    var id: String { rawValue }

    var defaultDescription: String {
        switch self {
        case .default:
            return "General fallback role."
        case .worker:
            return "Execution-focused role for implementation and fixes."
        case .explorer:
            return "Read-focused role for repository exploration."
        case .monitor:
            return "Long-running task monitor role optimized for wait/poll workflows."
        }
    }
}

@MainActor
@Observable
final class CodexAdvancedConfigViewModel {
    var preferredModelDraft: String = ""
    var errorMessage: String?
    var pathStatus: CodexBinaryManager.CodexPathStatus?
    var isConfiguringPath = false
    var isCheckingPath = false
    var models: [CodexModelsCache.Model] = []
    var activeModelSlug: String?
    var selectedReasoningEffort: String?
    var isApplyingModel = false
    var isApplyingReasoning = false
    var modelsCacheSourcePath: String?
    var modelsCacheFetchedAt: Date?
    var modelsCacheClientVersion: String?
    var modelsCacheETag: String?
    var pendingConflict: CodexLinkConflict?
    var linkStates: [CodexLinkFolder: CodexLinkState] = [:]
    var applyingLinkFolders: Set<CodexLinkFolder> = []
    var configFileURL: URL?
    var isSavingConfig = false
    var configErrorMessage: String?
    var approvalPolicyDraft: String = ""
    var sandboxModeDraft: String = ""
    var webSearchDraft: String = ""
    var modelProviderDraft: String = ""
    var profileDraft: String = ""
    var personalityDraft: String = ""
    var hideAgentReasoningDraft: Bool?
    var modelAutoCompactTokenLimitDraft: String = ""
    var compactPromptDraft: String = ""
    var experimentalCompactPromptFileDraft: String = ""
    var reasoningSummaryDraft: String = ""
    var verbosityDraft: String = ""
    var historyPersistenceDraft: String = ""
    var historyMaxBytesDraft: String = ""
    var agentsMaxThreadsDraft: String = ""
    var agentsMaxDepthDraft: String = ""
    var featureValues: [String: Bool] = [:]
    var roleDrafts: [CodexAgentRoleDraft] = []
    var preservedTopLevelRawValues: [String: String] = [:]
    var preservedHistoryRawValues: [String: String] = [:]

    private var provider: Provider
    private let manager: CodexBinaryManager
    private let linkService: CodexLinkService
    private let modelPreferenceService: CodexModelPreferenceService
    private let patchService = CodexStructuredConfigPatchService()
    private var isHydratingStructuredDraft = false
    private var hasLoadedStructuredDraft = false

    nonisolated deinit {}

    static let supportedFeatures: [CodexFeatureDefinition] = [
        .init(key: "undo", maturity: "Stable", description: "Create a ghost commit at each turn.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "shell_tool", maturity: "Stable", description: "Enable the default shell tool.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "unified_exec", maturity: "Stable", description: "Use the unified PTY-backed exec tool.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "shell_snapshot", maturity: "Stable", description: "Snapshot shell env for repeated commands.", source: "codex docs + codex features list"),
        .init(key: "web_search_request", maturity: "Deprecated", description: "Legacy live web search toggle.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "web_search_cached", maturity: "Deprecated", description: "Legacy cached web search toggle.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "codex_hooks", maturity: "Under Development", description: "Enable lifecycle hooks loaded from hooks.json.", source: "codex docs"),
        .init(key: "fast_mode", maturity: "Stable", description: "Enable Fast mode selection and the service_tier fast path.", source: "codex docs"),
        .init(key: "search_tool", maturity: "Under Development", description: "Enable search_tool_bm25 tool discovery.", source: "codex-rs/core/src/features.rs"),
        .init(key: "runtime_metrics", maturity: "Under Development", description: "Show runtime metrics summaries in TUI.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "sqlite", maturity: "Under Development", description: "Persist rollout metadata to local SQLite.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "memory_tool", maturity: "Under Development", description: "Enable startup memory extraction and consolidation.", source: "codex-rs/core/src/features.rs"),
        .init(key: "child_agents_md", maturity: "Under Development", description: "Append additional AGENTS.md guidance.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "apply_patch_freeform", maturity: "Under Development", description: "Enable freeform apply_patch tool mode.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "exec_policy", maturity: "Under Development", description: "Enable exec policy pipeline.", source: "codex features list (local CLI)"),
        .init(key: "use_linux_sandbox_bwrap", maturity: "Under Development", description: "Use Linux bubblewrap sandbox pipeline.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "request_rule", maturity: "Stable", description: "Enable smart approval prefix rule suggestions.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "experimental_windows_sandbox", maturity: "Under Development", description: "Enable Windows restricted-token sandbox.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "elevated_windows_sandbox", maturity: "Under Development", description: "Enable elevated Windows sandbox runner.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "remote_compaction", maturity: "Under Development", description: "Enable remote compaction flow.", source: "codex features list (local CLI)"),
        .init(key: "remote_models", maturity: "Under Development", description: "Refresh remote model list before readiness.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "powershell_utf8", maturity: "Under Development", description: "Enforce UTF8 output in PowerShell.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "enable_request_compression", maturity: "Stable", description: "Enable compressed request bodies.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "collab", maturity: "Experimental", description: "Enable collab/sub-agent tools.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "apps", maturity: "Experimental", description: "Enable ChatGPT Apps/connectors support.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "smart_approvals", maturity: "Experimental", description: "Route eligible approval requests through the guardian reviewer subagent.", source: "codex docs"),
        .init(key: "skill_mcp_dependency_install", maturity: "Stable", description: "Allow installing missing MCP dependencies for skills.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "skill_env_var_dependency_prompt", maturity: "Under Development", description: "Prompt for missing skill env var dependencies.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "steer", maturity: "Stable", description: "Enable steer mode behavior.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "collaboration_modes", maturity: "Stable", description: "Enable collaboration modes such as plan mode.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "personality", maturity: "Stable", description: "Enable personality selection controls.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "responses_websockets", maturity: "Under Development", description: "Use Responses API WebSocket transport by default.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "responses_websockets_v2", maturity: "Under Development", description: "Enable Responses API websocket v2 mode.", source: "codex-rs/core/src/features.rs"),
        .init(key: "multi_agent", maturity: "Stable", description: "Enable multi-agent collaboration tools.", source: "codex docs + Nolon config support"),
        .init(key: "apps_mcp_gateway", maturity: "Experimental", description: "Use the Apps MCP gateway endpoint.", source: "codex docs + Nolon config support"),
        .init(key: "web_search", maturity: "Deprecated", description: "Legacy web_search feature toggle.", source: "legacy compatibility (Nolon)"),
    ]

    init(
        provider: Provider,
        manager: CodexBinaryManager = .shared,
        linkService: CodexLinkService = CodexLinkService(),
        modelPreferenceService: CodexModelPreferenceService = CodexModelPreferenceService()
    ) {
        self.provider = provider
        self.manager = manager
        self.linkService = linkService
        self.modelPreferenceService = modelPreferenceService
    }

    func updateProvider(_ provider: Provider) {
        self.provider = provider
    }

    var isCodexXcodeProvider: Bool {
        if provider.templateId == "codexXcode" { return true }
        let expanded = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        return expanded.contains("/Library/Developer/Xcode/CodingAssistant/codex")
    }

    var visibleModels: [CodexModelsCache.Model] {
        models.filter { model in
            let visibility = model.visibility?.lowercased()
            return visibility == nil || visibility == "list"
        }
    }

    var activeModel: CodexModelsCache.Model? {
        if let activeModelSlug {
            return models.first(where: { $0.slug == activeModelSlug })
        }
        return nil
    }

    var hasHiddenActiveModel: Bool {
        guard let activeModelSlug else { return false }
        guard models.contains(where: { $0.slug == activeModelSlug }) else { return false }
        return !visibleModels.contains(where: { $0.slug == activeModelSlug })
    }

    var availableReasoningEfforts: [String] {
        guard let activeModel else { return [] }
        var unique: [String] = []
        for effort in activeModel.supportedReasoningLevels.map(\.effort) {
            let trimmed = effort.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !unique.contains(trimmed) {
                unique.append(trimmed)
            }
        }
        return unique
    }

    func load() async {
        loadModelsCache()
        loadSelectionsFromConfig()
        loadConfigDraft()
        if isCodexXcodeProvider {
            pathStatus = nil
            refreshLinkStates()
        } else {
            await refreshPathStatus()
            linkStates = [:]
        }
    }

    func applySelectedModel() async {
        do {
            let trimmed = preferredModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            try await manager.applyModelToConfig(trimmed, configFile: resolvedConfigFile())
            preferredModelDraft = trimmed
            activeModelSlug = trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPreferredModel() async {
        do {
            try await manager.clearPreferredModel(configFile: resolvedConfigFile())
            preferredModelDraft = ""
            activeModelSlug = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activateModel(_ model: CodexModelsCache.Model) async {
        isApplyingModel = true
        defer { isApplyingModel = false }
        do {
            try await manager.applyModelToConfig(model.slug, configFile: resolvedConfigFile())
            activeModelSlug = model.slug
            preferredModelDraft = model.slug
            await normalizeReasoningEffortForActiveModel(persist: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyReasoningEffort(_ effort: String?) async {
        let normalized = effort?.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = availableReasoningEfforts
        if let normalized, !normalized.isEmpty, !options.contains(normalized) {
            return
        }
        isApplyingReasoning = true
        defer { isApplyingReasoning = false }
        do {
            try await manager.setModelReasoningEffort(
                normalized?.isEmpty == false ? normalized : nil,
                configFile: resolvedConfigFile()
            )
            selectedReasoningEffort = normalized?.isEmpty == false ? normalized : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openModelConfig() {
        let configFile = resolvedConfigFile()
        let configPath = configFile ?? STFile("\(NSHomeDirectory())/.codex/config.toml")
        do {
            _ = STFolder(configPath.url.deletingLastPathComponent()).createIfNotExists()
            if !configPath.isExists {
                let initialModel = preferredModelDraft.nonEmpty ?? "gpt-5.3-codex"
                try "model = \"\(initialModel)\"\n".write(to: configPath.url, atomically: true, encoding: .utf8)
            }
            NSWorkspace.shared.open(configPath.url)
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

    func requestSetLink(_ enabled: Bool, folder: CodexLinkFolder) async {
        if enabled {
            guard let state = linkStates[folder] else { return }
            if state.isLinked { return }
            if state.hasVisibleEntries {
                pendingConflict = CodexLinkConflict(folder: folder, targetURL: state.targetURL)
                return
            }
            await setLink(enabled: true, folder: folder)
            return
        }

        await setLink(enabled: false, folder: folder)
    }

    func confirmPendingConflict() async {
        guard let pendingConflict else { return }
        let folder = pendingConflict.folder
        self.pendingConflict = nil
        await setLink(enabled: true, folder: folder)
    }

    func openFinderForPendingConflict() {
        guard let pendingConflict else { return }
        NSWorkspace.shared.activateFileViewerSelecting([pendingConflict.targetURL])
    }

    func refreshLinkStates() {
        guard isCodexXcodeProvider else {
            linkStates = [:]
            return
        }

        var result: [CodexLinkFolder: CodexLinkState] = [:]
        for folder in CodexLinkFolder.allCases {
            let status = linkService.status(folder: map(folder), provider: provider)
            result[folder] = CodexLinkState(
                folder: folder,
                sourceURL: status.sourceURL,
                targetURL: status.targetURL,
                isLinked: status.isLinked,
                hasVisibleEntries: status.hasVisibleEntries
            )
        }
        linkStates = result
    }

    func linkState(for folder: CodexLinkFolder) -> CodexLinkState {
        if let cached = linkStates[folder] {
            return cached
        }
        let pair = linkService.linkPair(folder: map(folder), provider: provider)
        return CodexLinkState(
            folder: folder,
            sourceURL: pair.sourceURL,
            targetURL: pair.targetURL,
            isLinked: false,
            hasVisibleEntries: false
        )
    }

    private func setLink(enabled: Bool, folder: CodexLinkFolder) async {
        guard isCodexXcodeProvider else { return }
        applyingLinkFolders.insert(folder)
        defer { applyingLinkFolders.remove(folder) }

        do {
            try linkService.apply(enabled: enabled, folder: map(folder), provider: provider)
            refreshLinkStates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadModelsCache() {
        let snapshot = modelPreferenceService.loadModelsCache(for: provider)
        models = snapshot.models
        modelsCacheSourcePath = snapshot.sourcePath
        modelsCacheFetchedAt = snapshot.fetchedAt
        modelsCacheClientVersion = snapshot.clientVersion
        modelsCacheETag = snapshot.etag

        if let activeModelSlug, !models.contains(where: { $0.slug == activeModelSlug }) {
            self.activeModelSlug = nil
        }
    }

    func featureEnabled(_ key: String) -> Bool {
        featureValues[key] ?? false
    }

    func setFeature(_ key: String, enabled: Bool) {
        featureValues[key] = enabled
        if key == "multi_agent", !enabled {
            roleDrafts = []
            agentsMaxDepthDraft = ""
            agentsMaxThreadsDraft = ""
        }
    }

    static func makeEmptyRoleDraft() -> CodexAgentRoleDraft {
        CodexAgentRoleDraft(
            name: "",
            description: "",
            configFile: "",
            model: "",
            modelReasoningEffort: "",
            modelReasoningSummary: "",
            modelVerbosity: "",
            sandboxMode: "",
            approvalPolicy: "",
            personality: "",
            webSearch: ""
        )
    }

    static func makeBuiltinRoleDraft(_ builtinRole: CodexBuiltinAgentRole) -> CodexAgentRoleDraft {
        CodexAgentRoleDraft(
            name: builtinRole.rawValue,
            description: builtinRole.defaultDescription,
            configFile: "",
            model: "",
            modelReasoningEffort: "",
            modelReasoningSummary: "",
            modelVerbosity: "",
            sandboxMode: "",
            approvalPolicy: "",
            personality: "",
            webSearch: ""
        )
    }

    @discardableResult
    func addRoleDraft(_ role: CodexAgentRoleDraft? = nil) -> UUID {
        let role = role ?? Self.makeEmptyRoleDraft()
        roleDrafts.append(role)
        return role.id
    }

    @discardableResult
    func upsertBuiltinRole(_ builtinRole: CodexBuiltinAgentRole) -> UUID {
        if let index = roleDrafts.firstIndex(where: { $0.name == builtinRole.rawValue }) {
            roleDrafts[index].description = builtinRole.defaultDescription
            return roleDrafts[index].id
        }

        let role = Self.makeBuiltinRoleDraft(builtinRole)
        roleDrafts.append(role)
        return role.id
    }

    func removeRoleDraft(_ id: UUID) {
        roleDrafts.removeAll { $0.id == id }
    }

    func saveStructuredConfig() async {
        guard let configFile = resolvedConfigFile() else { return }
        isSavingConfig = true
        defer { isSavingConfig = false }

        do {
            let original = (try? configFile.read()) ?? ""
            let patched = try patchService.patch(original: original, draft: makeStructuredDraft())
            try configFile.overlay(with: patched)
            loadConfigDraft()
        } catch {
            configErrorMessage = error.localizedDescription
        }
    }

    func scheduleStructuredSaveIfReady() {
        guard hasLoadedStructuredDraft, !isHydratingStructuredDraft else { return }
        Task { await saveStructuredConfig() }
    }

    private func resolvedConfigFile() -> STFile? {
        modelPreferenceService.resolvedConfigFile(for: provider)
    }

    func loadConfigDraft() {
        guard let configFile = resolvedConfigFile() else { return }
        isHydratingStructuredDraft = true
        defer {
            isHydratingStructuredDraft = false
            hasLoadedStructuredDraft = true
        }
        configFileURL = configFile.url
        let original = (try? configFile.read()) ?? ""
        let draft = patchService.extractDraft(from: original)

        approvalPolicyDraft = draft.approvalPolicy ?? ""
        sandboxModeDraft = draft.sandboxMode ?? ""
        webSearchDraft = draft.webSearch ?? ""
        modelProviderDraft = draft.modelProvider ?? ""
        profileDraft = draft.profile ?? ""
        personalityDraft = draft.personality ?? ""
        hideAgentReasoningDraft = draft.hideAgentReasoning
        modelAutoCompactTokenLimitDraft = draft.modelAutoCompactTokenLimit.map(String.init) ?? ""
        compactPromptDraft = draft.compactPrompt ?? ""
        experimentalCompactPromptFileDraft = draft.experimentalCompactPromptFile ?? ""
        reasoningSummaryDraft = draft.reasoningSummary ?? ""
        verbosityDraft = draft.verbosity ?? ""
        historyPersistenceDraft = draft.historyPersistence ?? ""
        historyMaxBytesDraft = draft.historyMaxBytes.map(String.init) ?? ""
        agentsMaxThreadsDraft = draft.agentsMaxThreads.map(String.init) ?? ""
        agentsMaxDepthDraft = draft.agentsMaxDepth.map(String.init) ?? ""
        featureValues = draft.featureValues
        preservedTopLevelRawValues = draft.preservedTopLevelRawValues
        preservedHistoryRawValues = draft.preservedHistoryRawValues
        roleDrafts = draft.roleDrafts.map { role in
            var role = role
            role.preservedRawValues = draft.preservedRoleRawValues[role.name] ?? [:]
            return role
        }
    }

    private func loadSelectionsFromConfig() {
        guard let config = modelPreferenceService.loadConfig(for: provider) else {
            preferredModelDraft = ""
            activeModelSlug = nil
            selectedReasoningEffort = nil
            return
        }
        let model = config.model?.trimmingCharacters(in: .whitespacesAndNewlines)
        preferredModelDraft = model ?? ""
        activeModelSlug = model
        selectedReasoningEffort = config.modelReasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeReasoningEffortForActiveModel(persist: Bool) async {
        let options = availableReasoningEfforts
        if options.isEmpty {
            if persist {
                try? await manager.setModelReasoningEffort(nil, configFile: resolvedConfigFile())
            }
            selectedReasoningEffort = nil
            return
        }

        if let selectedReasoningEffort, options.contains(selectedReasoningEffort) {
            return
        }

        let fallback = [activeModel?.defaultReasoningLevel, options.first]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { options.contains($0) })

        selectedReasoningEffort = fallback
        if persist {
            try? await manager.setModelReasoningEffort(fallback, configFile: resolvedConfigFile())
        }
    }

    private func map(_ folder: CodexLinkFolder) -> CodexLinkFolderKind {
        switch folder {
        case .prompts: return .prompts
        case .rules: return .rules
        case .skills: return .skills
        }
    }

    private func makeStructuredDraft() -> CodexAdvancedStructuredDraft {
        CodexAdvancedStructuredDraft(
            approvalPolicy: approvalPolicyDraft.nonEmpty,
            sandboxMode: sandboxModeDraft.nonEmpty,
            webSearch: webSearchDraft.nonEmpty,
            modelProvider: modelProviderDraft.nonEmpty,
            profile: profileDraft.nonEmpty,
            personality: personalityDraft.nonEmpty,
            hideAgentReasoning: hideAgentReasoningDraft,
            modelAutoCompactTokenLimit: Int(modelAutoCompactTokenLimitDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            compactPrompt: compactPromptDraft.nonEmpty,
            experimentalCompactPromptFile: experimentalCompactPromptFileDraft.nonEmpty,
            reasoningSummary: reasoningSummaryDraft.nonEmpty,
            verbosity: verbosityDraft.nonEmpty,
            historyPersistence: historyPersistenceDraft.nonEmpty,
            historyMaxBytes: Int(historyMaxBytesDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            featureValues: featureValues,
            agentsMaxThreads: Int(agentsMaxThreadsDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            agentsMaxDepth: Int(agentsMaxDepthDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            roleDrafts: roleDrafts,
            preservedTopLevelRawValues: preservedTopLevelRawValues,
            preservedHistoryRawValues: preservedHistoryRawValues,
            preservedRoleRawValues: Dictionary(uniqueKeysWithValues: roleDrafts.compactMap { role in
                let name = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !role.preservedRawValues.isEmpty else { return nil }
                return (name, role.preservedRawValues)
            })
        )
    }
}

struct CodexAdvancedConfigView: View {
    private struct RoleEditorTarget: Identifiable {
        enum Mode: Equatable {
            case existing(UUID)
            case creating
        }

        let mode: Mode

        var id: String {
            switch mode {
            case .existing(let roleID):
                return "existing-\(roleID.uuidString)"
            case .creating:
                return "creating"
            }
        }
    }

    private enum FilePickerTarget: String, Identifiable {
        case experimentalCompactPromptFile
        case roleConfigFile

        var id: String { rawValue }
    }

    private enum LargeTextEditorTarget: String, Identifiable {
        case compactPrompt

        var id: String { rawValue }
    }

    let provider: Provider
    let markerBaseItems: [PageMarkerItem]
    @State private var viewModel: CodexAdvancedConfigViewModel
    @State private var isEditingRawConfig = false
    @State private var roleEditorTarget: RoleEditorTarget?
    @State private var pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
    @State private var featureSearchText: String = ""
    @State private var filePickerTarget: FilePickerTarget?
    @State private var textEditorTarget: LargeTextEditorTarget?

    init(provider: Provider, markerBaseItems: [PageMarkerItem] = []) {
        self.provider = provider
        self.markerBaseItems = markerBaseItems
        self._viewModel = State(initialValue: CodexAdvancedConfigViewModel(provider: provider))
    }

    var body: some View {
        NolonUI.ProviderTabScrollScaffold {
                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString("codex.advanced.config.options.title", value: "Common Options", comment: "Common options")
                )
                commonOptionsSection

                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString("codex.advanced.config.features.title", value: "Feature Flags", comment: "Feature flags")
                )
                featureFlagsSection

                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString("codex.advanced.config.runtime.title", value: "History & Compaction", comment: "History and compaction")
                )
                runtimeControlsSection

                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString("codex.advanced.config.multi_agent.title", value: "Multi-Agent Roles", comment: "Multi-agent roles")
                )
                multiAgentSection

                if viewModel.isCodexXcodeProvider {
                    NolonUI.CodexAdvancedSectionHeaderView(
                        title: NSLocalizedString("codex.advanced.xcode_links.title", value: "Xcode Folder Links", comment: "Xcode folder links section title")
                    )
                    xcodeFolderLinksSection
                }
        }
        .textSelection(.enabled)
        .task(id: provider.id) {
            viewModel.updateProvider(provider)
            await viewModel.load()
        }
        .sheet(isPresented: $isEditingRawConfig) {
            if let configURL = viewModel.configFileURL {
                CodexConfigEditorView(configURL: configURL) {
                    viewModel.loadConfigDraft()
                }
            } else {
                EmptyView()
            }
        }
        .sheet(item: $roleEditorTarget) { target in
            roleEditorSheet(for: target)
        }
        .sheet(item: $textEditorTarget) { target in
            largeTextEditorSheet(for: target)
        }
        .fileImporter(
            isPresented: Binding(
                get: { filePickerTarget != nil },
                set: { if !$0 { filePickerTarget = nil } }
            ),
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .messageAlert(
            title: NSLocalizedString("codex.binary.error.title", value: "Binary Error", comment: "Binary error"),
            message: $viewModel.errorMessage
        )
        .messageAlert(
            title: NSLocalizedString("codex.advanced.config.error.title", value: "Config Error", comment: "Config error"),
            message: $viewModel.configErrorMessage
        )
        .triActionAlert(
            data: linkConflictAlertData,
            isPresented: Binding(
                get: { viewModel.pendingConflict != nil },
                set: { if !$0 { viewModel.pendingConflict = nil } }
            ),
            onDestructive: {
                Task { await viewModel.confirmPendingConflict() }
            },
            onSecondary: {
                viewModel.openFinderForPendingConflict()
            },
            onCancel: {}
        )
    }

    private var commonOptionsSection: some View {
        NolonUI.CodexAdvancedSectionCardView {
            runtimeOverviewSection

            if !viewModel.isCodexXcodeProvider, viewModel.pathStatus?.configured != true {
                Divider().padding(.vertical, 6)
                NolonUI.CodexPathStatusBarView(
                    data: pathStatusBarData,
                    onConfigure: {
                        Task { await viewModel.installPath() }
                    },
                    onCheck: {
                        Task { await viewModel.refreshPathStatus() }
                    }
                )
            }

            Divider().padding(.vertical, 4)

            availableModelsSection

            Divider()

            commonOptionPickerRow(
                title: "approval_policy",
                selection: $viewModel.approvalPolicyDraft,
                description: NSLocalizedString(
                    "codex.config.description.approval_policy",
                    value: "Controls when Codex asks for permission before running sensitive commands.",
                    comment: "Description for approval_policy"
                ),
                options: mergedOptions(
                    current: viewModel.approvalPolicyDraft,
                    defaults: ["untrusted", "on-request", "never"]
                ),
                quickOptions: ["untrusted", "on-request", "never"]
            )
            commonOptionPickerRow(
                title: "sandbox_mode",
                selection: $viewModel.sandboxModeDraft,
                description: localizedConfigDescription(
                    key: "sandbox_mode",
                    fallback: "Controls the filesystem and network sandbox level available to Codex."
                ),
                options: mergedOptions(
                    current: viewModel.sandboxModeDraft,
                    defaults: ["read-only", "workspace-write", "danger-full-access"]
                ),
                quickOptions: ["read-only", "workspace-write", "danger-full-access"]
            )
            commonOptionPickerRow(
                title: "web_search",
                selection: $viewModel.webSearchDraft,
                description: localizedConfigDescription(
                    key: "web_search",
                    fallback: "Controls whether Codex uses cached or live web results, or disables web search entirely."
                ),
                options: mergedOptions(
                    current: viewModel.webSearchDraft,
                    defaults: ["cached", "live", "disabled"]
                ),
                quickOptions: ["cached", "live", "disabled"]
            )
            commonOptionRow(
                title: "model_provider",
                text: $viewModel.modelProviderDraft,
                description: localizedConfigDescription(
                    key: "model_provider",
                    fallback: "Overrides which provider preset supplies model defaults and credentials."
                )
            )
            commonOptionRow(
                title: "profile",
                text: $viewModel.profileDraft,
                description: localizedConfigDescription(
                    key: "profile",
                    fallback: "Selects the named profile block to merge into the active configuration."
                )
            )
            commonOptionPickerRow(
                title: "personality",
                selection: $viewModel.personalityDraft,
                description: localizedConfigDescription(
                    key: "personality",
                    fallback: "Adjusts the default assistant tone for Codex sessions."
                ),
                options: mergedOptions(
                    current: viewModel.personalityDraft,
                    defaults: ["none", "friendly", "pragmatic"]
                ),
                quickOptions: ["none", "friendly", "pragmatic"]
            )
            commonOptionPickerRow(
                title: "model_reasoning_summary",
                selection: $viewModel.reasoningSummaryDraft,
                description: localizedConfigDescription(
                    key: "model_reasoning_summary",
                    fallback: "Controls whether Codex shows a reasoning summary in responses."
                ),
                options: mergedOptions(
                    current: viewModel.reasoningSummaryDraft,
                    defaults: ["none", "auto", "concise", "detailed"]
                ),
                quickOptions: ["none", "auto", "concise", "detailed"]
            )
            commonOptionPickerRow(
                title: "model_verbosity",
                selection: $viewModel.verbosityDraft,
                description: NSLocalizedString(
                    "codex.config.description.model_verbosity",
                    value: "Sets response detail level. Low is concise, high is more detailed.",
                    comment: "Description for model_verbosity"
                ),
                options: mergedOptions(
                    current: viewModel.verbosityDraft,
                    defaults: ["low", "medium", "high"]
                ),
                quickOptions: ["low", "medium", "high"]
            )

            Divider()

            NolonUI.CodexAdvancedTrailingActionRowView(
                title: NSLocalizedString("codex.advanced.config.edit_raw", value: "Edit Raw TOML", comment: "Edit raw TOML"),
                onTap: {
                    isEditingRawConfig = true
                }
            )

            docsRow(commonOptionDocs)
        }
        .debugCardLocator(sectionMarkerItems("Common Options"))
    }

    private var linkConflictAlertData: TriActionAlertData {
        TriActionAlertData(
            title: NSLocalizedString("codex.advanced.link.conflict.title", value: "Directory Contains Files", comment: "Conflict title"),
            message: NSLocalizedString(
                "codex.advanced.link.conflict.message",
                value: "The target folder already contains files. Confirm to delete its visible contents and replace it with a symlink.",
                comment: "Conflict message"
            ),
            destructiveTitle: NSLocalizedString("codex.advanced.link.confirm", value: "Confirm", comment: "Confirm action"),
            secondaryTitle: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
            cancelTitle: NSLocalizedString("action.cancel", comment: "Cancel")
        )
    }

    private var featureFlagsSection: some View {
        let knownKeys = Set(CodexAdvancedConfigViewModel.supportedFeatures.map(\.key))
        let extraFeatures = viewModel.featureValues.keys
            .filter { !knownKeys.contains($0) }
            .sorted()
            .map { key in
                CodexFeatureDefinition(
                    key: key,
                    maturity: NSLocalizedString("codex.features.maturity.unknown", value: "Unknown", comment: "Unknown feature maturity"),
                    description: NSLocalizedString(
                        "codex.features.description.unrecognized",
                        value: "Detected from config.toml but not in current built-in feature registry.",
                        comment: "Unrecognized feature description"
                    ),
                    source: NSLocalizedString(
                        "codex.features.source.config_unrecognized",
                        value: "config.toml (unrecognized key)",
                        comment: "Unrecognized feature source"
                    )
                )
            }
        let query = featureSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let renderedFeatures = (CodexAdvancedConfigViewModel.supportedFeatures + extraFeatures)
            .sorted { lhs, rhs in
                let lhsRank = featureSortRank(lhs.maturity)
                let rhsRank = featureSortRank(rhs.maturity)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.key < rhs.key
            }
            .filter { feature in
                guard !query.isEmpty else { return true }
                let values = [
                    feature.key,
                    feature.maturity,
                    localizedMaturityLabel(feature.maturity),
                    localizedFeatureDescription(feature),
                    feature.source
                ]
                return values.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        let renderedRows = renderedFeatures.map { feature in
            featureRowData(feature: feature, query: query)
        }

        return VStack(spacing: 10) {
            NolonUI.CodexAdvancedFeatureFlagsSectionView(
                searchText: $featureSearchText,
                rows: renderedRows,
                onToggle: { featureID, newValue in
                    viewModel.setFeature(featureID, enabled: newValue)
                    viewModel.scheduleStructuredSaveIfReady()
                }
            )
            docsRow([
                .init(id: "config-basics-features", title: "Config Basics", url: CodexAdvancedDocs.configBasics),
                .init(id: "config-reference-features", title: "Config Reference", url: CodexAdvancedDocs.configReference)
            ])
        }
        .debugCardLocator(sectionMarkerItems("Feature Flags"))
    }

    private var runtimeControlsSection: some View {
        NolonUI.CodexAdvancedSectionCardView {
            commonOptionPickerRow(
                title: "history.persistence",
                selection: $viewModel.historyPersistenceDraft,
                description: localizedConfigDescription(
                    key: "history.persistence",
                    fallback: "Control whether Codex saves transcripts to history.jsonl."
                ),
                options: mergedOptions(
                    current: viewModel.historyPersistenceDraft,
                    defaults: ["save-all", "none"]
                ),
                quickOptions: ["save-all", "none"]
            )
            numericInputRow(
                label: "history.max_bytes",
                text: $viewModel.historyMaxBytesDraft,
                description: localizedConfigDescription(
                    key: "history.max_bytes",
                    fallback: "Sets the maximum size of the local history file before old entries are trimmed."
                ),
                presets: historyMaxBytesPresets
            )
            triStateBoolRow(
                title: "hide_agent_reasoning",
                description: localizedConfigDescription(
                    key: "hide_agent_reasoning",
                    fallback: "Suppress reasoning events in the TUI and codex exec output."
                ),
                value: $viewModel.hideAgentReasoningDraft
            )
            numericInputRow(
                label: "model_auto_compact_token_limit",
                text: $viewModel.modelAutoCompactTokenLimitDraft,
                description: localizedConfigDescription(
                    key: "model_auto_compact_token_limit",
                    fallback: "Automatically compacts conversation history after the token count crosses this threshold."
                ),
                presets: autoCompactTokenPresets
            )
            largeTextOptionRow(
                title: "compact_prompt",
                text: $viewModel.compactPromptDraft,
                description: localizedConfigDescription(
                    key: "compact_prompt",
                    fallback: "Inline override for the history compaction prompt."
                )
            )
            filePathOptionRow(
                title: "experimental_compact_prompt_file",
                text: $viewModel.experimentalCompactPromptFileDraft,
                description: localizedConfigDescription(
                    key: "experimental_compact_prompt_file",
                    fallback: "Load the compaction prompt override from a file."
                ),
                pickerTarget: .experimentalCompactPromptFile
            )

            docsRow(runtimeDocs)
        }
        .debugCardLocator(sectionMarkerItems("History & Compaction"))
    }

    private func featureSortRank(_ maturity: String) -> Int {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") { return 0 }
        if normalized.contains("experimental") || normalized.contains("beta") { return 1 }
        return 2
    }

    private func localizedMaturityLabel(_ maturity: String) -> String {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") {
            return NSLocalizedString("codex.features.maturity.stable", value: "Stable", comment: "Stable maturity")
        }
        if normalized.contains("experimental") {
            return NSLocalizedString("codex.features.maturity.experimental", value: "Experimental", comment: "Experimental maturity")
        }
        if normalized.contains("beta") {
            return NSLocalizedString("codex.features.maturity.beta", value: "Beta", comment: "Beta maturity")
        }
        if normalized.contains("under_development") || normalized.contains("underdevelopment") {
            return NSLocalizedString("codex.features.maturity.under_development", value: "Under Development", comment: "Under development maturity")
        }
        if normalized.contains("deprecated") {
            return NSLocalizedString("codex.features.maturity.deprecated", value: "Deprecated", comment: "Deprecated maturity")
        }
        if normalized.contains("removed") {
            return NSLocalizedString("codex.features.maturity.removed", value: "Removed", comment: "Removed maturity")
        }
        return NSLocalizedString("codex.features.maturity.unknown", value: "Unknown", comment: "Unknown feature maturity")
    }

    private func localizedFeatureDescription(_ feature: CodexFeatureDefinition) -> String {
        let key = "codex.features.description.\(feature.key)"
        return NSLocalizedString(
            key,
            value: feature.description,
            comment: "Feature description"
        )
    }

    private func normalizedMaturityToken(_ maturity: String) -> String {
        maturity
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func sourceTag(for source: String) -> CodexFeatureSourceTag {
        let normalized = source.lowercased()

        // Priority: app server / cli list > docs > core > compatibility > config unknown
        if normalized.contains("app-server") {
            return .appServer
        }
        if normalized.contains("codex features list") {
            return .cliFeaturesList
        }
        if normalized.contains("codex docs") {
            return .codexDocs
        }
        if normalized.contains("codex-rs/core/src/features.rs") {
            return .coreFeatures
        }
        if normalized.contains("legacy") || normalized.contains("compatibility") {
            return .nolonCompatibility
        }
        if normalized.contains("unrecognized") || normalized.contains("unknown") || normalized.contains("config.toml") {
            return .configUnknown
        }
        return .nolonCompatibility
    }

    private func maturityChipTone(_ maturity: String) -> CodexFeatureChipTone {
        let normalized = normalizedMaturityToken(maturity)
        if normalized.contains("stable") {
            return .success
        }
        if normalized.contains("experimental") || normalized.contains("beta") || normalized.contains("under_development") || normalized.contains("underdevelopment") {
            return .warning
        }
        if normalized.contains("deprecated") || normalized.contains("removed") {
            return .error
        }
        return .secondary
    }

    private func sourceChipTone(_ source: CodexFeatureSourceTag) -> CodexFeatureChipTone {
        switch source {
        case .appServer, .cliFeaturesList:
            return .success
        case .codexDocs:
            return .info
        case .coreFeatures:
            return .warning
        case .nolonCompatibility, .configUnknown:
            return .secondary
        }
    }

    private func featureRowData(feature: CodexFeatureDefinition, query: String) -> CodexAdvancedFeatureRowData {
        let source = sourceTag(for: feature.source)
        return CodexAdvancedFeatureRowData(
            id: feature.id,
            keyText: feature.key,
            descriptionText: localizedFeatureDescription(feature),
            maturityText: localizedMaturityLabel(feature.maturity),
            sourceText: source.localizedTitle,
            queryText: query,
            maturityTone: maturityChipTone(feature.maturity),
            sourceTone: sourceChipTone(source),
            isEnabled: viewModel.featureEnabled(feature.key)
        )
    }

    private var multiAgentSection: some View {
        NolonUI.CodexAdvancedSectionCardView {
            NolonUI.CodexAdvancedMultiAgentToggleRowView(
                data: multiAgentToggleRowData,
                onToggle: { newValue in
                    viewModel.setFeature("multi_agent", enabled: newValue)
                    viewModel.scheduleStructuredSaveIfReady()
                }
            )

            NolonUI.CodexAdvancedMultiAgentStatusRowView(
                data: multiAgentStatusRowData
            )

            numericInputRow(
                label: "agents.max_threads",
                text: $viewModel.agentsMaxThreadsDraft,
                presets: agentThreadPresets
            )
            numericInputRow(
                label: "agents.max_depth",
                text: $viewModel.agentsMaxDepthDraft,
                presets: agentDepthPresets
            )

            NolonUI.CodexAdvancedRoleListView(
                emptyText: NSLocalizedString(
                    "codex.advanced.config.multi_agent.empty",
                    value: "No roles configured yet. Click Add Role to create the first role.",
                    comment: "No multi-agent roles"
                ),
                roles: roleListRows,
                onEdit: { roleID in
                    guard let roleUUID = UUID(uuidString: roleID) else { return }
                    roleEditorTarget = RoleEditorTarget(mode: .existing(roleUUID))
                },
                onDelete: { roleID in
                    guard let roleUUID = UUID(uuidString: roleID) else { return }
                    viewModel.removeRoleDraft(roleUUID)
                    if case .existing(let editingID) = roleEditorTarget?.mode, editingID == roleUUID {
                        roleEditorTarget = nil
                    }
                }
            )

            NolonUI.CodexAdvancedRoleSectionFooterView(
                addTitle: NSLocalizedString(
                    "codex.advanced.config.multi_agent.add_role",
                    value: "Add Role",
                    comment: "Add role"
                ),
                saveTitle: NSLocalizedString("action.save", value: "Save", comment: "Save"),
                isSaveDisabled: viewModel.isSavingConfig
            ) {
                NolonUI.CodexAdvancedRoleAddMenuContentView(
                    addEmptyTitle: NSLocalizedString(
                        "codex.advanced.config.multi_agent.add_role.empty",
                        value: "Add Empty Role",
                        comment: "Add empty role"
                    ),
                    builtinItems: roleAddBuiltinItems,
                    onAddEmpty: {
                        pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
                        roleEditorTarget = RoleEditorTarget(mode: .creating)
                    },
                    onSelectBuiltin: { builtinRoleRawValue in
                        guard let builtinRole = CodexBuiltinAgentRole(rawValue: builtinRoleRawValue) else { return }
                        if viewModel.roleDrafts.contains(where: { $0.name == builtinRole.rawValue }) {
                            let roleID = viewModel.upsertBuiltinRole(builtinRole)
                            roleEditorTarget = RoleEditorTarget(mode: .existing(roleID))
                        } else {
                            pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeBuiltinRoleDraft(builtinRole)
                            roleEditorTarget = RoleEditorTarget(mode: .creating)
                        }
                    }
                )
            } onSave: {
                    Task { await viewModel.saveStructuredConfig() }
            }

            docsRow(multiAgentDocs)
        }
        .debugCardLocator(sectionMarkerItems("Multi-Agent Roles"))
    }

    @ViewBuilder
    private func roleEditorSheet(for target: RoleEditorTarget) -> some View {
        if let role = roleBinding(for: target) {
            NolonUI.CodexAdvancedEditorScaffold(
                config: .init(
                    title: role.wrappedValue.name.nonEmpty ?? NSLocalizedString(
                        "codex.advanced.config.multi_agent.unnamed_role",
                        value: "Unnamed Role",
                        comment: "Unnamed role"
                    )
                )
            ) {
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("name"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.role_name",
                            value: "role name",
                            comment: "Role name placeholder"
                        ),
                        text: role.name
                    )
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("description"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.description",
                            value: "description",
                            comment: "Role description placeholder"
                        ),
                        text: role.description
                    )
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("config_file"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.config_file",
                            value: "config file path",
                            comment: "Role config file placeholder"
                        ),
                        text: role.configFile
                    )
                    HStack {
                        Spacer()
                        if !role.wrappedValue.configFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                                role.wrappedValue.configFile = ""
                                viewModel.scheduleStructuredSaveIfReady()
                            }
                            .buttonStyle(.borderless)
                        }
                        Button(NSLocalizedString("codex.advanced.action.choose_file", value: "Choose File", comment: "Choose file")) {
                            filePickerTarget = .roleConfigFile
                        }
                        .buttonStyle(.borderless)
                    }
                    NolonUI.CodexAdvancedRoleTextFieldRowView(
                        label: localizedConfigLabel("model"),
                        placeholder: NSLocalizedString(
                            "codex.advanced.config.multi_agent.model",
                            value: "model",
                            comment: "Role model placeholder"
                        ),
                        text: role.model
                    )
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("model_reasoning_effort"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "model_reasoning_effort", value: "")
                        )] + ["minimal", "low", "medium", "high", "xhigh"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "model_reasoning_effort", value: $0)
                            )
                        },
                        selection: role.modelReasoningEffort,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "model_reasoning_effort", selection: role.modelReasoningEffort, options: ["minimal", "low", "medium", "high", "xhigh"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("model_reasoning_summary"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "model_reasoning_summary", value: "")
                        )] + ["auto", "concise", "detailed", "none"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "model_reasoning_summary", value: $0)
                            )
                        },
                        selection: role.modelReasoningSummary,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "model_reasoning_summary", selection: role.modelReasoningSummary, options: ["none", "auto", "concise", "detailed"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("model_verbosity"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "model_verbosity", value: "")
                        )] + ["low", "medium", "high"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "model_verbosity", value: $0)
                            )
                        },
                        selection: role.modelVerbosity,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "model_verbosity", selection: role.modelVerbosity, options: ["low", "medium", "high"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("sandbox_mode"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "sandbox_mode", value: "")
                        )] + ["read-only", "workspace-write", "danger-full-access"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "sandbox_mode", value: $0)
                            )
                        },
                        selection: role.sandboxMode,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "sandbox_mode", selection: role.sandboxMode, options: ["read-only", "workspace-write", "danger-full-access"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("approval_policy"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "approval_policy", value: "")
                        )] + ["untrusted", "on-request", "never"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "approval_policy", value: $0)
                            )
                        },
                        selection: role.approvalPolicy,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "approval_policy", selection: role.approvalPolicy, options: ["untrusted", "on-request", "never"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("personality"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "personality", value: "")
                        )] + ["none", "friendly", "pragmatic"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "personality", value: $0)
                            )
                        },
                        selection: role.personality,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "personality", selection: role.personality, options: ["none", "friendly", "pragmatic"])
                    NolonUI.CodexAdvancedRolePickerRowView(
                        label: localizedConfigLabel("web_search"),
                        options: [CodexAdvancedPickerOption(
                            id: "",
                            title: localizedOptionLabel(key: "web_search", value: "")
                        )] + ["cached", "live", "disabled"].map {
                            CodexAdvancedPickerOption(
                                id: $0,
                                title: localizedOptionLabel(key: "web_search", value: $0)
                            )
                        },
                        selection: role.webSearch,
                        onSelectionChanged: {
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    )
                    quickOptionButtons(key: "web_search", selection: role.webSearch, options: ["cached", "live", "disabled"])

                    Divider().padding(.top, 4)

                    NolonUI.CodexAdvancedEditorFooterView(
                        closeTitle: NSLocalizedString("generic.close", value: "Close", comment: "Close"),
                        saveTitle: NSLocalizedString("action.save", value: "Save", comment: "Save"),
                        isSaveDisabled: viewModel.isSavingConfig,
                        onClose: {
                            closeRoleEditor(target)
                        },
                        onSave: {
                            commitRoleEditorIfNeeded(target)
                            Task { await viewModel.saveStructuredConfig() }
                            closeRoleEditor(target)
                        }
                    )
            }
        } else {
            EmptyView()
        }
    }

    private func roleBinding(for target: RoleEditorTarget) -> Binding<CodexAgentRoleDraft>? {
        switch target.mode {
        case .creating:
            return Binding(
                get: { pendingNewRoleDraft },
                set: { pendingNewRoleDraft = $0 }
            )
        case .existing(let roleID):
            guard let index = viewModel.roleDrafts.firstIndex(where: { $0.id == roleID }) else {
                return nil
            }
            return $viewModel.roleDrafts[index]
        }
    }

    private func commitRoleEditorIfNeeded(_ target: RoleEditorTarget) {
        if case .creating = target.mode {
            _ = viewModel.addRoleDraft(pendingNewRoleDraft)
            pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
        }
    }

    private func closeRoleEditor(_ target: RoleEditorTarget) {
        if case .creating = target.mode {
            pendingNewRoleDraft = CodexAdvancedConfigViewModel.makeEmptyRoleDraft()
        }
        roleEditorTarget = nil
    }

    private func commonOptionRow(title: String, text: Binding<String>, description: String? = nil) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            HStack(spacing: 8) {
                TextField(localizedConfigLabel(title), text: text)
                    .onChange(of: text.wrappedValue) { _, _ in
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

                if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                        text.wrappedValue = ""
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func triStateBoolRow(title: String, description: String? = nil, value: Binding<Bool?>) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            Picker(
                "",
                selection: Binding<String>(
                    get: {
                        switch value.wrappedValue {
                        case true: return "true"
                        case false: return "false"
                        case nil: return ""
                        }
                    },
                    set: { newValue in
                        switch newValue {
                        case "true": value.wrappedValue = true
                        case "false": value.wrappedValue = false
                        default: value.wrappedValue = nil
                        }
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                )
            ) {
                Text(NSLocalizedString("codex.config.option.unset", value: "Unset", comment: "Unset option")).tag("")
                Text(NSLocalizedString("codex.config.option.boolean.false", value: "Off", comment: "Boolean off")).tag("false")
                Text(NSLocalizedString("codex.config.option.boolean.true", value: "On", comment: "Boolean on")).tag("true")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func filePathOptionRow(
        title: String,
        text: Binding<String>,
        description: String? = nil,
        pickerTarget: FilePickerTarget
    ) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            HStack(spacing: 8) {
                TextField(localizedConfigLabel(title), text: text)
                    .onChange(of: text.wrappedValue) { _, _ in
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)

                Button(NSLocalizedString("codex.advanced.action.choose_file", value: "Choose File", comment: "Choose file")) {
                    filePickerTarget = pickerTarget
                }
                .buttonStyle(.borderless)

                if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(NSLocalizedString("action.show_in_finder", value: "Show in Finder", comment: "Show in Finder")) {
                        NSWorkspace.shared.selectFile(text.wrappedValue, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.borderless)

                    Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                        text.wrappedValue = ""
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func largeTextOptionRow(title: String, text: Binding<String>, description: String? = nil) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(title),
            description: description
        ) {
            HStack(spacing: 8) {
                Text(
                    text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? NSLocalizedString("codex.advanced.value.empty", value: "Not configured", comment: "Not configured")
                        : text.wrappedValue
                )
                .font(.caption)
                .foregroundStyle(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Button(NSLocalizedString("codex.advanced.action.edit_text", value: "Edit", comment: "Edit text")) {
                    textEditorTarget = .compactPrompt
                }
                .buttonStyle(.borderless)

                if !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                        text.wrappedValue = ""
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    private func numericInputRow(
        label: String,
        text: Binding<String>,
        description: String? = nil,
        presets: [String] = []
    ) -> some View {
        NolonUI.CodexAdvancedAlignedConfigRow(
            label: localizedConfigLabel(label),
            description: description
        ) {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("", text: text)
                        .onChange(of: text.wrappedValue) { _, newValue in
                            let filtered = newValue.filter(\.isNumber)
                            if filtered != newValue {
                                text.wrappedValue = filtered
                                return
                            }
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 180)

                    if !text.wrappedValue.isEmpty {
                        Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                            text.wrappedValue = ""
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if !presets.isEmpty {
                    quickValueButtons(selection: text, options: presets)
                }
            }
        }
        .debugCardLocator(itemMarkerItems(label))
    }

    private func commonOptionPickerRow(
        title: String,
        selection: Binding<String>,
        description: String? = nil,
        options: [String],
        quickOptions: [String] = []
    ) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            NolonUI.CodexAdvancedPickerRowView(
                label: localizedConfigLabel(title),
                description: description,
                options: [CodexAdvancedPickerOption(
                    id: "",
                    title: localizedOptionLabel(key: title, value: "")
                )] + options.map {
                    CodexAdvancedPickerOption(
                        id: $0,
                        title: localizedOptionLabel(key: title, value: $0)
                    )
                },
                selection: selection,
                onSelectionChanged: {
                    viewModel.scheduleStructuredSaveIfReady()
                }
            )

            if !quickOptions.isEmpty {
                quickOptionButtons(
                    key: title,
                    selection: selection,
                    options: quickOptions
                )
            }
        }
        .debugCardLocator(itemMarkerItems(title))
    }

    @ViewBuilder
    private func quickOptionButtons(key: String, selection: Binding<String>, options: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option
                    Button(localizedOptionLabel(key: key, value: option)) {
                        selection.wrappedValue = selection.wrappedValue == option ? "" : option
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func quickValueButtons(selection: Binding<String>, options: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue == option
                    Button(option) {
                        selection.wrappedValue = selection.wrappedValue == option ? "" : option
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var commonOptionDocs: [CodexConfigDocLink] {
        [
            .init(id: "config-basics", title: "Config Basics", url: CodexAdvancedDocs.configBasics),
            .init(id: "config-reference", title: "Config Reference", url: CodexAdvancedDocs.configReference),
            .init(id: "sandbox", title: "Sandboxing", url: CodexAdvancedDocs.sandboxing),
            .init(id: "approvals", title: "Approvals", url: CodexAdvancedDocs.approvals),
            .init(id: "models", title: "Models", url: CodexAdvancedDocs.models)
        ]
    }

    private var runtimeDocs: [CodexConfigDocLink] {
        [
            .init(id: "config-reference-runtime", title: "Config Reference", url: CodexAdvancedDocs.configReference),
            .init(id: "config-advanced-runtime", title: "Advanced Config", url: CodexAdvancedDocs.configAdvanced)
        ]
    }

    private var multiAgentDocs: [CodexConfigDocLink] {
        [
            .init(id: "subagents", title: "Subagents", url: CodexAdvancedDocs.subagents),
            .init(id: "config-reference-subagents", title: "Config Reference", url: CodexAdvancedDocs.configReference)
        ]
    }

    @ViewBuilder
    private func docsRow(_ links: [CodexConfigDocLink]) -> some View {
        if !links.isEmpty {
            Divider().padding(.top, 2)
            HStack(spacing: 8) {
                Text(NSLocalizedString("codex.advanced.docs.title", value: "Official Docs", comment: "Official docs"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(links) { link in
                    Button(link.title) {
                        openURL(link.url)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func openURL(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func mergedOptions(current: String, defaults: [String]) -> [String] {
        var options = defaults
        let normalized = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty && !options.contains(normalized) {
            options.insert(normalized, at: 0)
        }
        return options
    }

    private func localizedConfigLabel(_ key: String) -> String {
        NSLocalizedString("codex.config.label.\(key)", value: key, comment: "Codex config field label")
    }

    private func localizedConfigDescription(key: String, fallback: String) -> String {
        NSLocalizedString("codex.config.description.\(key)", value: fallback, comment: "Codex config field description")
    }

    private func localizedOptionLabel(key: String, value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return NSLocalizedString("codex.config.option.unset", value: "Unset", comment: "Unset option")
        }
        let optionKey = "codex.config.option.\(key).\(normalized)"
        return NSLocalizedString(optionKey, value: normalized, comment: "Codex config option value")
    }

    @ViewBuilder
    private func largeTextEditorSheet(for target: LargeTextEditorTarget) -> some View {
        switch target {
        case .compactPrompt:
            VStack(alignment: .leading, spacing: 12) {
                Text(localizedConfigLabel("compact_prompt"))
                    .font(.headline)
                Text(localizedConfigDescription(
                    key: "compact_prompt",
                    fallback: "Inline override for the history compaction prompt."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.compactPromptDraft)
                    .font(.body.monospaced())
                    .frame(minWidth: 560, minHeight: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                HStack {
                    if !viewModel.compactPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(NSLocalizedString("action.clear", value: "Clear", comment: "Clear")) {
                            viewModel.compactPromptDraft = ""
                            viewModel.scheduleStructuredSaveIfReady()
                        }
                    }
                    Spacer()
                    Button(NSLocalizedString("generic.close", value: "Close", comment: "Close")) {
                        textEditorTarget = nil
                        viewModel.scheduleStructuredSaveIfReady()
                    }
                }
            }
            .padding(20)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let target = filePickerTarget else { return }
        defer { filePickerTarget = nil }
        guard case .success(let urls) = result, let url = urls.first else { return }
        let path = url.path
        switch target {
        case .experimentalCompactPromptFile:
            viewModel.experimentalCompactPromptFileDraft = path
        case .roleConfigFile:
            pendingNewRoleDraft.configFile = path
            if case .existing(let roleID) = roleEditorTarget?.mode,
               let index = viewModel.roleDrafts.firstIndex(where: { $0.id == roleID }) {
                viewModel.roleDrafts[index].configFile = path
            }
        }
        viewModel.scheduleStructuredSaveIfReady()
    }

    private var historyMaxBytesPresets: [String] { ["5242880", "20971520", "104857600"] }
    private var autoCompactTokenPresets: [String] { ["32000", "64000", "128000"] }
    private var agentThreadPresets: [String] { ["4", "8", "16"] }
    private var agentDepthPresets: [String] { ["2", "4", "8"] }

    private var runtimeOverviewSection: some View {
        NolonUI.CodexAdvancedRuntimeOverviewView(
            stats: runtimeOverviewStats,
            metaRows: runtimeOverviewMetaRows
        )
    }

    private var availableModelsSection: some View {
        let visibleModels = viewModel.visibleModels
        return NolonUI.CodexAdvancedModelsCacheSectionView(
            title: NSLocalizedString(
                "codex.advanced.models_cache.title",
                value: "Models Cache",
                comment: "Models cache section title"
            ),
            isApplyingModel: viewModel.isApplyingModel,
            reasoningLabel: NSLocalizedString(
                "codex.advanced.models_cache.reasoning_effort",
                value: "Reasoning Effort",
                comment: "Reasoning effort title"
            ),
            reasoningOptions: reasoningEffortOptions,
            reasoningSelection: Binding(
                get: { viewModel.selectedReasoningEffort ?? "__default__" },
                set: { value in
                    let effort = value == "__default__" ? nil : value
                    Task { await viewModel.applyReasoningEffort(effort) }
                }
            ),
            isReasoningDisabled: viewModel.availableReasoningEfforts.isEmpty
                || viewModel.isApplyingReasoning
                || viewModel.activeModel == nil,
            isApplyingReasoning: viewModel.isApplyingReasoning,
            showsReasoningUnsupportedHint: viewModel.availableReasoningEfforts.isEmpty,
            reasoningUnsupportedHintText: NSLocalizedString(
                "codex.advanced.models_cache.reasoning_effort.unsupported",
                value: "The active model does not support configurable reasoning effort.",
                comment: "Reasoning unsupported text"
            ),
            isModelsEmpty: viewModel.models.isEmpty,
            modelsEmptyHintText: NSLocalizedString(
                "provider.binary.codex.model.empty",
                value: "No model list found in models_cache.json. Run Codex CLI once to refresh cache.",
                comment: "No cached model list"
            ),
            hasHiddenActiveModel: viewModel.hasHiddenActiveModel,
            hiddenActiveModelHintText: NSLocalizedString(
                "codex.advanced.models_cache.hidden_active_hint",
                value: "Current model is hidden from list. Activate a visible model to replace it.",
                comment: "Hidden active model hint"
            ),
            modelLabel: NSLocalizedString(
                "codex.advanced.models_cache.column.model",
                value: "Model",
                comment: "Model column title"
            ),
            modelOptions: visibleModels.map {
                CodexAdvancedPickerOption(id: $0.slug, title: $0.displayName)
            },
            modelSelection: Binding(
                get: { viewModel.activeModelSlug ?? "" },
                set: { slug in
                    guard
                        !slug.isEmpty,
                        slug != viewModel.activeModelSlug,
                        let model = visibleModels.first(where: { $0.slug == slug })
                    else { return }
                    Task { await viewModel.activateModel(model) }
                }
            ),
            isModelDisabled: viewModel.isApplyingModel || visibleModels.isEmpty
        )
    }

    private var reasoningEffortOptions: [CodexAdvancedPickerOption] {
        let defaultOption = CodexAdvancedPickerOption(
            id: "__default__",
            title: NSLocalizedString(
                "codex.advanced.models_cache.reasoning_effort.default",
                value: "Use Model Default",
                comment: "Default reasoning effort"
            )
        )
        let effortOptions = viewModel.availableReasoningEfforts.map {
            CodexAdvancedPickerOption(
                id: $0,
                title: localizedOptionLabel(key: "model_reasoning_effort", value: $0)
            )
        }
        return [defaultOption] + effortOptions
    }

    private var runtimeOverviewMetaRows: [CodexAdvancedMetaRowData] {
        var rows: [CodexAdvancedMetaRowData] = []
        if let sourcePath = viewModel.modelsCacheSourcePath, !sourcePath.isEmpty {
            rows.append(
                CodexAdvancedMetaRowData(
                    id: "sourcePath",
                    text: sourcePath,
                    isMonospaced: true
                )
            )
        }
        if let clientVersion = viewModel.modelsCacheClientVersion, !clientVersion.isEmpty {
            rows.append(
                CodexAdvancedMetaRowData(
                    id: "clientVersion",
                    text: "client: \(clientVersion)",
                    isMonospaced: false
                )
            )
        }
        return rows
    }

    private var xcodeFolderLinksSection: some View {
        NolonUI.CodexXcodeFolderLinksSectionView(
            descriptionText: NSLocalizedString(
                "codex.advanced.xcode_links.desc",
                value: "Link Xcode Codex folders to ~/.codex equivalents.",
                comment: "Xcode links description"
            ),
            cards: xcodeFolderLinkCards,
            onToggleLink: { folderID, enabled in
                guard let folder = CodexLinkFolder(rawValue: folderID) else { return }
                Task { await viewModel.requestSetLink(enabled, folder: folder) }
            },
            onShowInFinder: { folderID in
                guard let folder = CodexLinkFolder(rawValue: folderID) else { return }
                let state = viewModel.linkState(for: folder)
                NSWorkspace.shared.activateFileViewerSelecting([state.targetURL])
            }
        )
        .debugCardLocator(sectionMarkerItems("Xcode Folder Links"))
    }

    private var xcodeFolderLinkCards: [CodexXcodeFolderLinkCardData] {
        CodexLinkFolder.allCases.map { folder in
            let state = viewModel.linkState(for: folder)
            return xcodeFolderLinkCardData(folder: folder, state: state)
        }
    }

    private func sectionMarkerItems(_ title: String) -> [PageMarkerItem] {
        let prefix = markerBaseItems.isEmpty
            ? [
                PageMarkerItem(title: provider.displayName),
                PageMarkerItem(title: ProviderContentTabType.advanced.localizedName(for: provider))
            ]
            : markerBaseItems
        return prefix + [PageMarkerItem(title: title)]
    }

    private func itemMarkerItems(_ title: String) -> [PageMarkerItem] {
        let prefix = markerBaseItems.isEmpty
            ? [
                PageMarkerItem(title: provider.displayName),
                PageMarkerItem(title: ProviderContentTabType.advanced.localizedName(for: provider))
            ]
            : markerBaseItems
        return prefix + [PageMarkerItem(title: title)]
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func linkStatusText(isLinked: Bool) -> String {
        if isLinked {
            return NSLocalizedString("status.linked", value: "Linked", comment: "Linked status")
        }
        return NSLocalizedString("status.not_linked", value: "Not Linked", comment: "Not linked status")
    }

    private func xcodeFolderLinkCardData(
        folder: CodexLinkFolder,
        state: CodexLinkState
    ) -> CodexXcodeFolderLinkCardData {
        CodexXcodeFolderLinkCardData(
            id: folder.id,
            folderTitle: folder.rawValue.capitalized,
            statusText: linkStatusText(isLinked: state.isLinked),
            isLinked: state.isLinked,
            sourcePathText: "~/.codex/\(folder.rawValue)",
            targetPathText: displayPath(state.targetURL.path),
            hasVisibleEntries: state.hasVisibleEntries,
            conflictHintText: NSLocalizedString(
                "codex.advanced.link.conflict.short",
                value: "Contains visible files",
                comment: "Short conflict hint"
            ),
            showInFinderTitle: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
            isApplying: viewModel.applyingLinkFolders.contains(folder)
        )
    }

    private func roleRowData(_ role: CodexAgentRoleDraft) -> CodexAdvancedRoleRowData {
        CodexAdvancedRoleRowData(
            id: role.id.uuidString,
            title: role.name.nonEmpty ?? NSLocalizedString(
                "codex.advanced.config.multi_agent.unnamed_role",
                value: "Unnamed Role",
                comment: "Unnamed role"
            ),
            modelText: role.model.nonEmpty ?? "-",
            editTitle: NSLocalizedString("action.edit", value: "Edit", comment: "Edit action")
        )
    }

    private var roleListRows: [CodexAdvancedRoleRowData] {
        viewModel.roleDrafts.map(roleRowData)
    }

    private var multiAgentToggleRowData: CodexAdvancedMultiAgentToggleRowData {
        CodexAdvancedMultiAgentToggleRowData(
            labelText: NSLocalizedString(
                "codex.advanced.config.multi_agent.toggle_label",
                value: "[features].multi_agent",
                comment: "multi-agent toggle label"
            ),
            isEnabled: viewModel.featureEnabled("multi_agent")
        )
    }

    private var roleAddBuiltinItems: [CodexAdvancedRoleAddBuiltinItem] {
        CodexBuiltinAgentRole.allCases.map { builtinRole in
            CodexAdvancedRoleAddBuiltinItem(
                id: builtinRole.rawValue,
                title: String(
                    format: NSLocalizedString(
                        "codex.advanced.config.multi_agent.add_builtin.format",
                        value: "Add or Override: %@",
                        comment: "Add/override builtin role format"
                    ),
                    builtinRole.rawValue
                )
            )
        }
    }

    private var multiAgentStatusRowData: CodexAdvancedMultiAgentStatusRowData {
        let enabled = viewModel.featureEnabled("multi_agent")
        return CodexAdvancedMultiAgentStatusRowData(
            isEnabled: enabled,
            messageText: NSLocalizedString(
                enabled
                    ? "codex.advanced.config.multi_agent.status_enabled"
                    : "codex.advanced.config.multi_agent.status_disabled",
                value: enabled
                    ? "Multi-agent is enabled. You can edit roles and agents settings below."
                    : "Multi-agent is disabled. Enable the switch above to edit roles.",
                comment: "multi-agent status"
            )
        )
    }

    private var runtimeOverviewStats: [CodexAdvancedStatTileData] {
        [
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.active", value: "Active", comment: "Active model"),
                value: viewModel.activeModel?.displayName ?? "-"
            ),
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.total", value: "Total", comment: "Total models"),
                value: "\(viewModel.visibleModels.count)"
            ),
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.reasoning_effort", value: "Reasoning Effort", comment: "Reasoning effort title"),
                value: viewModel.selectedReasoningEffort ?? NSLocalizedString(
                    "codex.advanced.models_cache.reasoning_effort.default",
                    value: "Use Model Default",
                    comment: "Default reasoning effort"
                )
            ),
            CodexAdvancedStatTileData(
                title: NSLocalizedString("codex.advanced.models_cache.meta.fetched_at", value: "Last Fetch", comment: "Last fetch"),
                value: viewModel.modelsCacheFetchedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-"
            )
        ]
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

    private var pathStatusBarData: CodexPathStatusBarData {
        CodexPathStatusBarData(
            title: NSLocalizedString("codex.binary.path.section", value: "Terminal PATH", comment: "PATH section title"),
            statusText: viewModel.pathStatus.map(pathStatusText),
            configureTitle: NSLocalizedString("codex.binary.path.configure", value: "Add to PATH", comment: "Add codex path to shell profile"),
            checkTitle: NSLocalizedString("codex.binary.path.check", value: "Check", comment: "Check PATH status"),
            isCheckingPath: viewModel.isCheckingPath,
            isConfiguringPath: viewModel.isConfiguringPath
        )
    }

}
